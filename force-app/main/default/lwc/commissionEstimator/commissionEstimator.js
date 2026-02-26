import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import calculateEstimate from '@salesforce/apex/CommissionCalculatorService.getEstimate';

import AMOUNT_FIELD from '@salesforce/schema/Opportunity.Amount';

const FIELDS = [AMOUNT_FIELD];

export default class CommissionEstimator extends LightningElement {
    @api recordId;

    dealAmount = 0;
    estimatedCommission = 0;
    isLoading = true;
    hasError = false;
    errorMessage = '';

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredOpportunity({ error, data }) {
        if (data) {
            this.dealAmount = getFieldValue(data, AMOUNT_FIELD) || 0;
            this.loadEstimate();
        } else if (error) {
            this.handleError(error);
        }
    }

    async loadEstimate() {
        this.isLoading = true;
        this.hasError = false;

        try {
            if (this.dealAmount > 0) {
                this.estimatedCommission = await calculateEstimate({ amount: this.dealAmount });
            } else {
                this.estimatedCommission = 0;
            }
        } catch (error) {
            this.handleError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleError(error) {
        this.hasError = true;
        this.isLoading = false;

        if (error.body && error.body.message) {
            this.errorMessage = error.body.message;
        } else if (error.message) {
            this.errorMessage = error.message;
        } else {
            this.errorMessage = 'An error occurred while calculating commission.';
        }
    }

    get hasCommission() {
        return this.estimatedCommission > 0;
    }

    get effectiveRateDisplay() {
        if (this.dealAmount <= 0) {
            return '0.00';
        }
        const rate = (this.estimatedCommission / this.dealAmount) * 100;
        return rate.toFixed(2);
    }

    get commissionPercentage() {
        if (this.dealAmount <= 0) {
            return 0;
        }
        return Math.min((this.estimatedCommission / this.dealAmount) * 100 * 10, 100);
    }

    get progressBarStyle() {
        return `width: ${this.commissionPercentage}%;`;
    }
}
