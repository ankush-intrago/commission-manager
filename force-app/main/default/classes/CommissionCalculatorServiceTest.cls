/**
 * @description Test class for CommissionCalculatorService
 */
@IsTest
private class CommissionCalculatorServiceTest {

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
    static void testSingleTierCalculation() {
        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 25000, 'Prospecting');

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id, Amount__c, Rate_Applied__c, Status__c
            FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(1, statements.size(), 'Should create one statement');
        System.assertEquals(1250, statements[0].Amount__c, 'Commission should be 5% of 25000');
        System.assertEquals('Pending', statements[0].Status__c, 'Status should be Pending');
    }

    @IsTest
    static void testMultipleTierCalculation() {
        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 75000, 'Prospecting');

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id, Amount__c
            FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(1, statements.size(), 'Should create one statement');
        Decimal expected = (50000 * 0.05) + (25000 * 0.07);
        System.assertEquals(expected, statements[0].Amount__c, 'Should apply tiered rates');
    }

    @IsTest
    static void testHighTierCalculation() {
        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 150000, 'Prospecting');

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id, Amount__c
            FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(1, statements.size(), 'Should create one statement');
        Decimal expected = (50000 * 0.05) + (50000 * 0.07) + (50000 * 0.10);
        System.assertEquals(expected, statements[0].Amount__c, 'Should apply all tier rates');
    }

    @IsTest
    static void testSplitCommissions() {
        Commission_Plan__c splitPlan = CommissionTestDataFactory.createCommissionPlan(
            'Split Plan',
            Date.today().addDays(-30),
            Date.today().addDays(30),
            true
        );
        CommissionTestDataFactory.createSplitRules(splitPlan.Id);

        List<Commission_Plan__c> existingPlans = [
            SELECT Id FROM Commission_Plan__c
            WHERE Name = 'Test Plan'
        ];
        for (Commission_Plan__c p : existingPlans) {
            p.Is_Active__c = false;
        }
        update existingPlans;

        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 100000, 'Prospecting');

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id, Amount__c, Role__c
            FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
            ORDER BY Role__c
        ];

        System.assertEquals(3, statements.size(), 'Should create three statements for splits');

        Map<String, Decimal> expectedAmounts = new Map<String, Decimal>{
            'Manager' => 750,
            'Sales Engineer' => 1250,
            'Sales Rep' => 3000
        };

        for (Commission_Statement__c stmt : statements) {
            System.assertEquals(
                expectedAmounts.get(stmt.Role__c),
                stmt.Amount__c,
                'Amount should match split percentage for ' + stmt.Role__c
            );
        }
    }

    @IsTest
    static void testBulkCalculation() {
        Account acc = CommissionTestDataFactory.createAccount();
        List<Opportunity> opps = CommissionTestDataFactory.createOpportunities(
            acc.Id, 200, 10000, 'Prospecting'
        );

        Test.startTest();
        for (Opportunity opp : opps) {
            opp.StageName = 'Closed Won';
        }
        update opps;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id FROM Commission_Statement__c
        ];

        System.assertEquals(200, statements.size(), 'Should create 200 statements');
    }

    @IsTest
    static void testNoActivePlan() {
        List<Commission_Plan__c> plans = [SELECT Id FROM Commission_Plan__c];
        for (Commission_Plan__c p : plans) {
            p.Is_Active__c = false;
        }
        update plans;

        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 50000, 'Prospecting');

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(0, statements.size(), 'Should not create statements without active plan');
    }

    @IsTest
    static void testZeroAmount() {
        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 0, 'Prospecting');

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(0, statements.size(), 'Should not create statements for zero amount');
    }

    @IsTest
    static void testGetEstimate() {
        Test.startTest();
        Decimal estimate = CommissionCalculatorService.getEstimate(25000);
        Test.stopTest();

        System.assertEquals(1250, estimate, 'Estimate should be 5% of 25000');
    }

    @IsTest
    static void testGetEstimateNullAmount() {
        Test.startTest();
        Decimal estimate = CommissionCalculatorService.getEstimate(null);
        Test.stopTest();

        System.assertEquals(0, estimate, 'Estimate should be 0 for null amount');
    }

    @IsTest
    static void testEffectiveDating() {
        Commission_Plan__c futurePlan = CommissionTestDataFactory.createCommissionPlan(
            'Future Plan',
            Date.today().addDays(60),
            Date.today().addDays(90),
            true
        );

        List<Commission_Rule__c> futureRules = new List<Commission_Rule__c>();
        futureRules.add(new Commission_Rule__c(
            Name = 'Future Rule',
            Commission_Plan__c = futurePlan.Id,
            Min_Amount__c = 0,
            Max_Amount__c = null,
            Rate__c = 20,
            Role__c = 'Sales Rep',
            Split_Percentage__c = 100,
            Order__c = 1
        ));
        insert futureRules;

        Account acc = CommissionTestDataFactory.createAccount();
        Opportunity opp = CommissionTestDataFactory.createOpportunity(acc.Id, 50000, 'Prospecting');

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Commission_Statement__c> statements = [
            SELECT Id, Amount__c, Commission_Plan__c
            FROM Commission_Statement__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(1, statements.size(), 'Should use current plan, not future');
        System.assertNotEquals(futurePlan.Id, statements[0].Commission_Plan__c,
            'Should not use future dated plan');
    }
}
