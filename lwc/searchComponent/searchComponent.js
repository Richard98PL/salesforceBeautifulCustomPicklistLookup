import { LightningElement, api, track } from 'lwc';
import search from '@salesforce/apex/LeadFromContactController.search';
const DELAY = 215;
export default class SearchComponent extends LightningElement {

    @api objName;
    @api iconName;
    @api labelName;
    @api readOnly = false;
    @api placeholder;
    @api fields;

    @track required;
    @api requiredAsterisk;

    @track error;
    delayTimeout;
    searchRecords;
    selectedRecord;
    isLoading = false;

    ICON_URL = '/apexpages/slds/latest/assets/icons/{0}-sprite/svg/symbols.svg#{1}';
    searchIconClass;
    selectedIconClass;

    connectedCallback(){
        if(!this.requiredAsterisk){
            this.required = "display: none;"
        }

        let icons           = this.iconName.split(':');
        this.searchIconClass = 'slds-icon_container slds-icon-' + icons[0] + '-' + icons[1];
        this.selectedIconClass = 'slds-icon_container slds-combobox__input-entity-icon slds-icon-' + icons[0] + '-' + icons[1];

        this.ICON_URL       = this.ICON_URL.replace('{0}',icons[0]);
        this.ICON_URL       = this.ICON_URL.replace('{1}',icons[1]);

        let combinedFields = [];
        combinedFields.push(this.name, this.recordTypeName);

        this.fields = combinedFields.concat( JSON.parse(JSON.stringify(this.fields)) );
    }

    clearLookup(event){
       if(!event.relatedTarget || event.relatedTarget.type != ''){
           this.selectedRecord = undefined;
           this.searchRecords  = undefined;
           event.target.value = null;
       }
    }

    handleInputChange(event){
        event.target.addEventListener("focusout", (e) => this.clearLookup(e));

        window.clearTimeout(this.delayTimeout);
        const searchKey = event.target.value;
        if(searchKey){
            this.delayTimeout = setTimeout(() => {
                this.isLoading = true;
                search({
                    searchTerm : searchKey,
                    objName : this.objName
                })
                    .then(result => {
                        let stringResult = JSON.stringify(result);
                        let allResult    = JSON.parse(stringResult);
                        allResult.forEach( record => {
                            record.name = record['Name'].length > 30 ?
                            record['Name'].substring(0,27).trim()+'...':
                            record['Name'];
                            if(record['RecordType']['Name']){
                                record.recordTypeName = record['RecordType']['Name'];
                            }
                        });
                        this.searchRecords = allResult;
                    })
                    .catch(error => {
                        console.error('Error:', error);
                    })
                    .finally( ()=>{
                        this.isLoading = false;
                    });
            }, DELAY);
        }else{
            this.searchRecords = undefined;
        }
    }

    handleSelect(event){
        let recordId = event.currentTarget.dataset.recordId;
        let selectRecord = this.searchRecords.find((item) => {
            return item.Id === recordId;
        });

        selectRecord.name = selectRecord.name.length > 30 ?
            selectRecord.name.substring(0,27).trim()+'...':
            selectRecord.name;

        this.selectedRecord = selectRecord;

        let lookupEvent = new CustomEvent('lookup', {
            detail: {id: recordId, objName: this.objName}
        });
        this.dispatchEvent(lookupEvent);
    }

    handleClose(){
        this.selectedRecord = undefined;
        this.searchRecords  = undefined;
        let lookupEvent = new CustomEvent('lookup', {
            detail: {id: null, objName: this.objName},
            target : {objName : this.objName}
        });
        this.dispatchEvent(lookupEvent);
    }
}