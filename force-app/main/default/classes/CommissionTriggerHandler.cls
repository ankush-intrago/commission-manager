/**
 * @description Trigger handler for Opportunity trigger. Handles commission calculation
 *              on Closed Won and clawback processing on Closed Lost.
 */
public with sharing class CommissionTriggerHandler {

    /**
     * @description Handle after update trigger context
     * @param newOpps List of updated opportunities
     * @param oldMap Map of old opportunity values
     */
    public static void handleAfterUpdate(
        List<Opportunity> newOpps,
        Map<Id, Opportunity> oldMap
    ) {
        List<Opportunity> closedWonOpps = new List<Opportunity>();
        List<Opportunity> clawbackOpps = new List<Opportunity>();

        Commission_Setting__mdt settings = CommissionSelector.getDefaultSettings();
        String triggerStage = settings != null && String.isNotBlank(settings.Calculation_Trigger_Stage__c)
            ? settings.Calculation_Trigger_Stage__c
            : 'Closed Won';

        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldMap.get(opp.Id);

            if (opp.StageName == triggerStage && oldOpp.StageName != triggerStage) {
                closedWonOpps.add(opp);
            }

            if (opp.StageName == 'Closed Lost' && oldOpp.StageName == triggerStage) {
                clawbackOpps.add(opp);
            }
        }

        if (!closedWonOpps.isEmpty()) {
            processClosedWonOpportunities(closedWonOpps);
        }

        if (!clawbackOpps.isEmpty()) {
            CommissionClawbackService.processClawbacks(clawbackOpps);
        }
    }

    /**
     * @description Process closed won opportunities and create commission statements
     * @param opportunities List of closed won opportunities
     */
    private static void processClosedWonOpportunities(List<Opportunity> opportunities) {
        List<Commission_Statement__c> statements =
            CommissionCalculatorService.calculateCommissions(opportunities);

        if (!statements.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, statements
            );
            insert decision.getRecords();
        }
    }
}
