/**
 * @description Selector class for commission-related SOQL queries.
 *              All queries use USER_MODE for field-level security enforcement.
 */
public with sharing class CommissionSelector {

    /**
     * @description Get active commission plan for a given close date
     * @param closeDate The date to check for active plans
     * @return List of matching Commission Plans with their rules
     */
    public static List<Commission_Plan__c> getActivePlanForDate(Date closeDate) {
        return [
            SELECT Id, Name, Effective_Start_Date__c, Effective_End_Date__c,
                (SELECT Id, Name, Min_Amount__c, Max_Amount__c, Rate__c,
                        Role__c, Split_Percentage__c, Order__c
                 FROM Commission_Rules__r
                 ORDER BY Order__c ASC)
            FROM Commission_Plan__c
            WHERE Is_Active__c = true
            AND Effective_Start_Date__c <= :closeDate
            AND Effective_End_Date__c >= :closeDate
            WITH USER_MODE
            LIMIT 1
        ];
    }

    /**
     * @description Get commission statements for specific opportunities
     * @param opportunityIds Set of opportunity IDs
     * @return List of Commission Statements
     */
    public static List<Commission_Statement__c> getStatementsByOpportunityIds(Set<Id> opportunityIds) {
        return [
            SELECT Id, Opportunity__c, Amount__c, Status__c, Payee__c, Role__c
            FROM Commission_Statement__c
            WHERE Opportunity__c IN :opportunityIds
            AND Status__c != 'Clawback'
            WITH USER_MODE
        ];
    }

    /**
     * @description Get commission settings from custom metadata
     * @return Commission Setting record or null
     */
    public static Commission_Setting__mdt getDefaultSettings() {
        List<Commission_Setting__mdt> settings = [
            SELECT Default_Clawback_Days__c, Enable_Split_Commissions__c,
                   Calculation_Trigger_Stage__c
            FROM Commission_Setting__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        return settings.isEmpty() ? null : settings[0];
    }

    /**
     * @description Get opportunities with required fields for commission calculation
     * @param opportunityIds Set of opportunity IDs
     * @return List of Opportunities with necessary fields
     */
    public static List<Opportunity> getOpportunitiesById(Set<Id> opportunityIds) {
        return [
            SELECT Id, Name, Amount, CloseDate, OwnerId, StageName
            FROM Opportunity
            WHERE Id IN :opportunityIds
            WITH USER_MODE
        ];
    }

    /**
     * @description Get rules grouped by role for a specific plan
     * @param planId The Commission Plan ID
     * @return Map of Role to list of Commission Rules
     */
    public static Map<String, List<Commission_Rule__c>> getRulesByRoleForPlan(Id planId) {
        Map<String, List<Commission_Rule__c>> rulesByRole = new Map<String, List<Commission_Rule__c>>();

        List<Commission_Rule__c> rules = [
            SELECT Id, Name, Min_Amount__c, Max_Amount__c, Rate__c,
                   Role__c, Split_Percentage__c, Order__c
            FROM Commission_Rule__c
            WHERE Commission_Plan__c = :planId
            ORDER BY Role__c, Order__c ASC
            WITH USER_MODE
        ];

        for (Commission_Rule__c rule : rules) {
            if (!rulesByRole.containsKey(rule.Role__c)) {
                rulesByRole.put(rule.Role__c, new List<Commission_Rule__c>());
            }
            rulesByRole.get(rule.Role__c).add(rule);
        }

        return rulesByRole;
    }
}
