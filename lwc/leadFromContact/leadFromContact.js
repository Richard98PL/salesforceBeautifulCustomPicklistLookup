import {LightningElement, api, wire, track} from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import LEAD_OBJECT from '@salesforce/schema/Lead';
import createLeadAndCampaignMember from '@salesforce/apex/LeadFromContactController.createLeadAndCampaignMember';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import {NavigationMixin} from "lightning/navigation";

import successMessage from '@salesforce/label/c.leadFromContactSuccess';
import warningMessage from '@salesforce/label/c.leadFromContactWarning';
import errorMessage from '@salesforce/label/c.leadFromContactError';
import synchronizationMessage from '@salesforce/label/c.leadFromContactSync';
import cardTitle from '@salesforce/label/c.leadFromContactCardTitle';
import button from '@salesforce/label/c.leadFromContactButton';

import isPardotSynchronized from '@salesforce/schema/Contact.Is_Pardot_Synchronized__c';
import accountName from '@salesforce/schema/Contact.Account.Name';
import contactFirstName from '@salesforce/schema/Contact.FirstName';
import contactLastName from '@salesforce/schema/Contact.LastName';

import {getRecord, getFieldValue} from 'lightning/uiRecordApi';
const FIELDS = [isPardotSynchronized, accountName, contactFirstName, contactLastName];

export default class LeadFromContact extends NavigationMixin(LightningElement) {
    labels = {
        synchronizationMessage,
        cardTitle,
        button
    };

    @track campaignId;
    @track projectId;
    @track leadRecordTypeId;

    @track disableButton = true;
    fieldsWithRecordType = ['Name', 'RecordType.Name'];

    @api recordId;
    @api objectApiName;

    @track value;
    @track options;

    map;
    isLoading = true;
    isPardotSynchronized = true;
    accountName;
    name;
    contactLastName;
    contactFirstName;
    currentDate;
    leadInitialLastName;

    @wire(getRecord, { recordId:'$recordId', fields: FIELDS})
    loadFields({error, data}){
        if(error){
            console.log('error', JSON.parse(JSON.stringify(error)));
        }else if(data){
            //this.isPardotSynchronized = getFieldValue(data, isPardotSynchronized);
            this.isPardotSynchronized = true;
            this.accountName =  this.parseEmptyString(getFieldValue(data, accountName));

            this.contactFirstName =  this.parseEmptyString(getFieldValue(data, contactFirstName));
            this.contactLastName =  this.parseEmptyString(getFieldValue(data, contactLastName));

            this.leadFirstName = this.contactFirstName;

            let today = new Date();
            this.currentDate = today.getDate() + '/' + (today.getMonth() + 1) + '/' + today.getFullYear();

            this.leadInitialLastName = this.contactLastName;
            this.leadLastName = this.leadInitialLastName;

            this.setOfInputs.add('first-name');
            this.setOfInputs.add('last-name');
        }
        this.isLoading = false;
    }

    @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
    leadRecordTypesInit({error, data}) {
        if(data) {
            let parsedOptions = JSON.parse(JSON.stringify(data.recordTypeInfos));
            let map = new Map();
            let comboBoxValues = [];

            for(const [key,value] of Object.entries(parsedOptions)){
                let recordTypeName = value.name;

                if(recordTypeName == 'Master'){
                    continue;
                }

                map.set(recordTypeName, key);
                comboBoxValues.push({
                    value : key,
                    label : recordTypeName,
                    description : ""
                });
            }
            this.map = map;
            this.options = comboBoxValues;
        }
        else if(error) {
            console.log(error);
            this.showToast("Unexpected error. Please contact your Salesforce administrator.", "error");
            this.closeQuickAction();
        }
    }
    setOfInputs = new Set();
    howManyRequiredInputs = 5;
    handleChangeLeadRecordTypeId(event) {
        this.leadRecordTypeId = event.target.value;

        this.handleInput(event, false);
    }

    handleLookup(event){
        if(event.detail.objName == 'Campaign'){
            this.campaignId = event.detail.id;
        }else if(event.detail.objName == 'Project_TT__c'){
            this.projectId = event.detail.id;
        }

        this.handleInput(event, true);
    }

    handleInput(event, isFromDifferentComponent){
        let value;
        let target;
        if(isFromDifferentComponent){
            value = JSON.parse(JSON.stringify(event.detail)).id;
            target = JSON.parse(JSON.stringify(event.detail)).objName;
        }else{
            value = event.target.value;
            target = JSON.stringify(event.target.id);
            target = target.slice(0, target.lastIndexOf('-')).replaceAll('"','');
        }

        if(value){
            this.setOfInputs.add(target);
        }else{
            this.setOfInputs.delete(target);
        }

        this.disableButton = (this.setOfInputs.size != this.howManyRequiredInputs);
    }

    showToast(message, variant) {
        const evt = new ShowToastEvent({
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    navigateToLead(recordId) {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Lead',
                actionName: 'view'
            }
        }).then(url => {window.open(url,  "_blank")});
    }

    navigateToCampaign(recordId) {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.campaignId,
                objectApiName: 'Campaign',
                actionName: 'view'
            }
        }).then(url => {
            setTimeout(() => {
                window.open(url, "_blank")
                this.navigateToLead(recordId);
            },1000);
        });
    }

    handleButtonClick(event){
        this.isLoading = true;
        let leadWrapperToFunction = {
            contactId : this.recordId,
            campaignId : this.campaignId,
            projectId : this.projectId,
            leadRecordTypeId : this.leadRecordTypeId,

            description : this.description,
            leadItemOfInterest : this.itemOfInterest,

            leadFirstName : this.leadFirstName,
            leadLastName : this.leadLastName
        };

        createLeadAndCampaignMember({
            leadWrapper : leadWrapperToFunction
        })
            .then(result => {
                let response = result;
                if(response){
                    this.showToast(successMessage, "success");
                    this.navigateToCampaign(result);
                }else{
                    this.showToast(warningMessage, "warning");
                }
            })
            .catch(error => {
                console.log(error);
                this.showToast(errorMessage, "error");
            })
            .finally( ()=>{
                this.isLoading = false;
                this.closeQuickAction();
            });
    }

    description;
    descriptionChange(event){
        this.description = event.target.value;
    }
    itemOfInterest;
    itemOfInterestChange(event){
        this.itemOfInterest = event.target.value;
    }

    leadFirstName;
    leadFirstNameChange(event){
        this.leadFirstName = event.target.value;

        this.handleInput(event, false);
    }

    leadLastName;
    leadLastNameChange(event){
        this.leadLastName = event.target.value;

        this.handleInput(event, false);
    }

    parseEmptyString(string){
        if(string == undefined || string == null){
            return "";
        }else{
            return string;
        }
    }
}