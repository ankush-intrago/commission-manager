/**
 * @description Test class for CommissionTriggerHandler and clawback functionality
 */
@IsTest
private class CommissionTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        Commission_Plan__c plan = CommissionTestDataFactory.createCommissionPlan(
            'Test Plan',
            Date.today().addDays(-30),
            Date.today().addDays(30),
            true
        );
        CommissionTestDataFactory.createTieredRules(plan.Id);
    }

    @IsTest
    static void testClosedWonTrigger() {
        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 30000, 'Prospecting');

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id, Status__c, Amount__c
            FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(1, statements.size(), 'Statement should be created');
        System.assertEquals('Pending', statements[0].Status__c, 'Status should be Pending');
    }

    @IsTest
    static void testClawbackTrigger() {
        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 40000, 'Prospecting');

        opp.StageName = 'Closed Won';
        update opp;

        List<Commission_Statement__c> originalStatements = [
            SELECT Id, Amount__c
            FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
        ];
        System.assertEquals(1, originalStatements.size(), 'Original statement should exist');
        Decimal originalAmount = originalStatements[0].Amount__c;

        Test.startTest();
        opp.StageName = 'Closed Lost';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> allStatements = [
            SELECT Id, Amount__c, Status__c, Clawback_Reference__c
            FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
            ORDER BY CreatedDate ASC
        ];

        System.assertEquals(2, allStatements.size(), 'Should have original and clawback');

        Commission_Statement__c original = allStatements[0];
        Commission_Statement__c clawback = allStatements[1];

        System.assertEquals('Clawback', original.Status__c, 'Original should be marked as clawback');
        System.assertEquals('Clawback', clawback.Status__c, 'New statement should be clawback');
        System.assertEquals(-originalAmount, clawback.Amount__c, 'Clawback should be negative');
        System.assertEquals(original.Id, clawback.Clawback_Reference__c, 'Should reference original');
    }

    @IsTest
    static void testNoClawbackOutsidePeriod() {
        Account acc = CommissionTestDataFactory.createAccount();
        Commission_Plan__c plan = [SELECT Id FROM Commission_Plan__c LIMIT 1];

        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 40000, 'Closed Won');

        Commission_Statement__c oldStatement = new Commission_Statement__c(
            Opportunity__c = opp.Id,
            Commission_Plan__c = plan.Id,
            Payee__c = UserInfo.getUserId(),
            Amount__c = 2000,
            Status__c = 'Approved',
            Deal_Amount__c = 40000,
            Calculation_Date__c = Datetime.now().addDays(-100),
            Role__c = 'Sales Rep'
        );
        insert oldStatement;

        Test.startTest();
        opp.StageName = 'Closed Lost';
        update opp;
        Test.stopTest();

        Commission_Statement__c updatedStatement = [
            SELECT Id, Status__c
            FROM Commission_Statement__c
            WHERE Id = :oldStatement.Id
        ];

        System.assertEquals('Approved', updatedStatement.Status__c,
            'Old statement should not be clawed back');
    }

    @IsTest
    static void testMultipleOpportunitiesClawback() {
        Account acc = CommissionTestDataFactory.createAccount();
        List<Opportunity> opps = CommissionTestDataFactory.createOpportunities(
            acc.Id, 5, 20000, 'Prospecting'
        );

        for (Opportunity opp : opps) {
            opp.StageName = 'Closed Won';
        }
        update opps;

        Integer originalCount = [SELECT COUNT() FROM Commission_Statement__c];
        System.assertEquals(5, originalCount, 'Should have 5 original statements');

        Test.startTest();
        for (Opportunity opp : opps) {
            opp.StageName = 'Closed Lost';
        }
        update opps;
        Test.stopTest();

        Integer totalCount = [SELECT COUNT() FROM Commission_Statement__c];
        System.assertEquals(10, totalCount, 'Should have 10 total statements (5 original + 5 clawback)');

        Integer clawbackCount = [
            SELECT COUNT()
            FROM Commission_Statement__c
            WHERE Status__c = 'Clawback' AND Amount__c < 0
        ];
        System.assertEquals(5, clawbackCount, 'Should have 5 negative clawback statements');
    }

    @IsTest
    static void testStageChangeNotClosedWon() {
        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 30000, 'Prospecting');

        Test.startTest();
        opp.StageName = 'Qualification';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(0, statements.size(), 'No statement for non-Closed Won stage');
    }

    @IsTest
    static void testReClosedWon() {
        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 30000, 'Prospecting');

        opp.StageName = 'Closed Won';
        update opp;

        opp.StageName = 'Closed Lost';
        update opp;

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id, Status__c, Amount__c
            FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
            ORDER BY CreatedDate DESC
        ];

        System.assert(statements.size() >= 3, 'Should have multiple statements');
    }

    @IsTest
    static void testClawbackServiceDirectCall() {
        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 50000, 'Closed Won');
        Commission_Plan__c plan = [SELECT Id FROM Commission_Plan__c LIMIT 1];

        Commission_Statement__c stmt = CommissionTestDataFactory.createStatement(
            opp.Id, plan.Id, 2500, 'Pending'
        );

        List<Opportunity> oppsToClawback = new List<Opportunity>{ opp };

        Test.startTest();
        CommissionClawbackService.processClawbacks(oppsToClawback);
        Test.stopTest();

        List<Commission_Statement__c> clawbacks = [
            SELECT Id, Amount__c, Status__c
            FROM Commission_Statement__c
            WHERE Clawback_Reference__c = :stmt.Id
        ];

        System.assertEquals(1, clawbacks.size(), 'Should create clawback statement');
        System.assertEquals(-2500, clawbacks[0].Amount__c, 'Clawback should be negative');
    }
}
