/**
 * @description Service class for handling commission clawbacks when opportunities
 *              are lost after being closed won.
 */
public with sharing class CommissionClawbackService {

    /**
     * @description Process clawbacks for opportunities that moved from Closed Won to Closed Lost
     * @param opportunities List of opportunities that need clawback processing
     */
    public static void processClawbacks(List<Opportunity> opportunities) {
        if (opportunities == null || opportunities.isEmpty()) {
            return;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            opportunityIds.add(opp.Id);
        }

        List<Commission_Statement__c> existingStatements =
            CommissionSelector.getStatementsByOpportunityIds(opportunityIds);

        if (existingStatements.isEmpty()) {
            return;
        }

        Commission_Setting__mdt settings = CommissionSelector.getDefaultSettings();
        Integer clawbackDays = settings != null && settings.Default_Clawback_Days__c != null
            ? Integer.valueOf(settings.Default_Clawback_Days__c)
            : 90;

        List<Commission_Statement__c> clawbackStatements = new List<Commission_Statement__c>();
        List<Commission_Statement__c> statementsToUpdate = new List<Commission_Statement__c>();

        for (Commission_Statement__c statement : existingStatements) {
            if (!isWithinClawbackPeriod(statement.Calculation_Date__c, clawbackDays)) {
                continue;
            }

            Commission_Statement__c clawback = createClawbackStatement(statement);
            clawbackStatements.add(clawback);

            statement.Status__c = 'Clawback';
            statementsToUpdate.add(statement);
        }

        if (!clawbackStatements.isEmpty()) {
            SObjectAccessDecision insertDecision = Security.stripInaccessible(
                AccessType.CREATABLE, clawbackStatements
            );
            insert insertDecision.getRecords();
        }

        if (!statementsToUpdate.isEmpty()) {
            SObjectAccessDecision updateDecision = Security.stripInaccessible(
                AccessType.UPDATABLE, statementsToUpdate
            );
            update updateDecision.getRecords();
        }
    }

    /**
     * @description Check if a statement is within the clawback period
     * @param calculationDate The original calculation date
     * @param clawbackDays Number of days for clawback period
     * @return True if within clawback period
     */
    @TestVisible
    private static Boolean isWithinClawbackPeriod(Datetime calculationDate, Integer clawbackDays) {
        if (calculationDate == null) {
            return true;
        }

        Date calcDate = calculationDate.date();
        Date cutoffDate = calcDate.addDays(clawbackDays);

        return Date.today() <= cutoffDate;
    }

    /**
     * @description Create a clawback statement from an original statement
     * @param original The original commission statement
     * @return New clawback statement with negative amount
     */
    @TestVisible
    private static Commission_Statement__c createClawbackStatement(Commission_Statement__c original) {
        Commission_Statement__c clawback = new Commission_Statement__c();
        clawback.Opportunity__c = original.Opportunity__c;
        clawback.Commission_Plan__c = original.Commission_Plan__c;
        clawback.Payee__c = original.Payee__c;
        clawback.Amount__c = -original.Amount__c;
        clawback.Rate_Applied__c = original.Rate_Applied__c;
        clawback.Status__c = 'Clawback';
        clawback.Deal_Amount__c = original.Deal_Amount__c;
        clawback.Calculation_Date__c = Datetime.now();
        clawback.Clawback_Reference__c = original.Id;
        clawback.Role__c = original.Role__c;

        return clawback;
    }
}
