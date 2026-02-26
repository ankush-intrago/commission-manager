/**
 * @description Test data factory for commission management tests
 */
@IsTest
public class CommissionTestDataFactory {

    /**
     * @description Create a commission plan with tiered rules
     * @param planName Name of the plan
     * @param startDate Plan start date
     * @param endDate Plan end date
     * @param isActive Whether the plan is active
     * @return The created Commission Plan
     */
    public static Commission_Plan__c createCommissionPlan(
        String planName,
        Date startDate,
        Date endDate,
        Boolean isActive
    ) {
        Commission_Plan__c plan = new Commission_Plan__c(
            Name = planName,
            Effective_Start_Date__c = startDate,
            Effective_End_Date__c = endDate,
            Is_Active__c = isActive,
            Description__c = 'Test commission plan'
        );
        insert plan;
        return plan;
    }

    /**
     * @description Create default tiered commission rules for a plan
     * @param planId The Commission Plan ID
     * @return List of created Commission Rules
     */
    public static List<Commission_Rule__c> createTieredRules(Id planId) {
        List<Commission_Rule__c> rules = new List<Commission_Rule__c>();

        rules.add(new Commission_Rule__c(
            Name = 'Tier 1 - Sales Rep',
            Commission_Plan__c = planId,
            Min_Amount__c = 0,
            Max_Amount__c = 50000,
            Rate__c = 5,
            Role__c = 'Sales Rep',
            Split_Percentage__c = 100,
            Order__c = 1
        ));

        rules.add(new Commission_Rule__c(
            Name = 'Tier 2 - Sales Rep',
            Commission_Plan__c = planId,
            Min_Amount__c = 50000,
            Max_Amount__c = 100000,
            Rate__c = 7,
            Role__c = 'Sales Rep',
            Split_Percentage__c = 100,
            Order__c = 2
        ));

        rules.add(new Commission_Rule__c(
            Name = 'Tier 3 - Sales Rep',
            Commission_Plan__c = planId,
            Min_Amount__c = 100000,
            Max_Amount__c = null,
            Rate__c = 10,
            Role__c = 'Sales Rep',
            Split_Percentage__c = 100,
            Order__c = 3
        ));

        insert rules;
        return rules;
    }

    /**
     * @description Create split commission rules for multiple roles
     * @param planId The Commission Plan ID
     * @return List of created Commission Rules
     */
    public static List<Commission_Rule__c> createSplitRules(Id planId) {
        List<Commission_Rule__c> rules = new List<Commission_Rule__c>();

        rules.add(new Commission_Rule__c(
            Name = 'Sales Rep Rule',
            Commission_Plan__c = planId,
            Min_Amount__c = 0,
            Max_Amount__c = null,
            Rate__c = 5,
            Role__c = 'Sales Rep',
            Split_Percentage__c = 60,
            Order__c = 1
        ));

        rules.add(new Commission_Rule__c(
            Name = 'Sales Engineer Rule',
            Commission_Plan__c = planId,
            Min_Amount__c = 0,
            Max_Amount__c = null,
            Rate__c = 5,
            Role__c = 'Sales Engineer',
            Split_Percentage__c = 25,
            Order__c = 1
        ));

        rules.add(new Commission_Rule__c(
            Name = 'Manager Rule',
            Commission_Plan__c = planId,
            Min_Amount__c = 0,
            Max_Amount__c = null,
            Rate__c = 5,
            Role__c = 'Manager',
            Split_Percentage__c = 15,
            Order__c = 1
        ));

        insert rules;
        return rules;
    }

    /**
     * @description Create a test account
     * @return The created Account
     */
    public static Account createAccount() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        return acc;
    }

    /**
     * @description Create test opportunities
     * @param accountId The Account ID
     * @param count Number of opportunities to create
     * @param amount Amount for each opportunity
     * @param stageName Stage name for opportunities
     * @return List of created Opportunities
     */
    public static List<Opportunity> createOpportunities(
        Id accountId,
        Integer count,
        Decimal amount,
        String stageName
    ) {
        List<Opportunity> opps = new List<Opportunity>();

        for (Integer i = 0; i < count; i++) {
            opps.add(new Opportunity(
                Name = 'Test Opportunity ' + i,
                AccountId = accountId,
                Amount = amount,
                StageName = stageName,
                CloseDate = Date.today()
            ));
        }

        insert opps;
        return opps;
    }

    /**
     * @description Create a single test opportunity
     * @param accountId The Account ID
     * @param amount Opportunity amount
     * @param stageName Stage name
     * @return The created Opportunity
     */
    public static Opportunity createOpportunity(
        Id accountId,
        Decimal amount,
        String stageName
    ) {
        return createOpportunities(accountId, 1, amount, stageName)[0];
    }

    /**
     * @description Create a commission statement for testing
     * @param opportunityId The Opportunity ID
     * @param planId The Commission Plan ID
     * @param amount Commission amount
     * @param status Statement status
     * @return The created Commission Statement
     */
    public static Commission_Statement__c createStatement(
        Id opportunityId,
        Id planId,
        Decimal amount,
        String status
    ) {
        Commission_Statement__c statement = new Commission_Statement__c(
            Opportunity__c = opportunityId,
            Commission_Plan__c = planId,
            Payee__c = UserInfo.getUserId(),
            Amount__c = amount,
            Status__c = status,
            Deal_Amount__c = amount * 20,
            Calculation_Date__c = Datetime.now(),
            Role__c = 'Sales Rep'
        );
        insert statement;
        return statement;
    }
}
