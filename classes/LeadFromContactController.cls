public with sharing class LeadFromContactController {
    private static final Set<String> CONTACT_FIELDS = Contact.sObjectType.getDescribe().fields.getMap().keySet();
    private static final Set<String> LEAD_FIELDS = Lead.sObjectType.getDescribe().fields.getMap().keySet();
    private static Boolean validateId(String id) {
        return ((id.length() == 15 || id.length() == 18) && Pattern.matches('^[a-zA-Z0-9]*$', id));
    }

    @AuraEnabled
    public static List<sObject> search(String searchTerm, String objName){
        Set<String> objectFields = Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().keySet();
        Boolean hasRecordTypes = objectFields.contains('RecordTypeId'.toLowerCase());

        String query = 'SELECT Id,Name';
        if(hasRecordTypes){
            query+= ',RecordType.Name';
        }
        query += ' FROM ' + objName + ' WHERE (';
        query += 'Name LIKE \'' + searchTerm + '%\'';
        if(validateId(searchTerm)) {
            query += ' OR Id = \'' + searchTerm + '\'';
        }
        query += ' )';
        if(hasRecordTypes){
            query += ' AND RecordTypeId != null';
        }

        if(objName.toLowerCase() == 'campaign'){
            query += ' AND RecordType.DeveloperName = \'YIT_Business_Premises\'';
        }

        query += ' LIMIT 4';
        return Database.query(query);
    }


    @AuraEnabled
    public static String createLeadAndCampaignMember(LeadWrapper leadWrapper){
        System.debug(leadWrapper);
        Map<String,String> contactToLeadFields = new Map<String,String>();
        for(Lead_From_Contact_Configuration__mdt metadata: Lead_From_Contact_Configuration__mdt.getAll().values()) {
            contactToLeadFields.put(
                    String.valueOf(metadata.Contact_Field__c).toLowerCase(),
                    String.valueOf(metadata.Lead_Field__c).toLowerCase()
            );
        }

        Set<String> contactFields = new Set<String>();
        contactFields.addAll(contactToLeadFields.keySet());
        contactFields.add('id');

        String query = 'SELECT';
        for(String contactField: contactFields){
            if(CONTACT_FIELDS.contains(contactField.split('\\.')[0].toLowerCase()) ||
                    CONTACT_FIELDS.contains(contactField.split('\\.')[0].toLowerCase() + 'id')){
                query += ' ' + contactField + ',';
            }
        }
        query = query.removeEnd(',');
        query += ' FROM Contact WHERE Id = \'' + leadWrapper.contactId + '\'';

        Contact contact = Database.query(query);



        Lead lead = new Lead();
        for(String contactField : contactToLeadFields.keySet()){
            String leadFieldDeveloperName = contactToLeadFields.get(contactField).toLowerCase();
            if(!LEAD_FIELDS.contains(leadFieldDeveloperName) && !LEAD_FIELDS.contains(leadFieldDeveloperName + 'id')){
                continue;
            }

            String leadFieldValue;
            if(!contactField.contains('.')){
                leadFieldValue = String.valueOf(contact.get(contactField));
            }else{
                List<String> splitField = contactField.split('\\.');
                leadFieldValue = String.valueOf(contact.getSObject(splitField[0]).get(splitField[1]));
            }

            if(leadFieldValue == 'true' || leadFieldValue == 'false'){
                lead.put(leadFieldDeveloperName, Boolean.valueOf(leadFieldValue));
            }else{
                lead.put(leadFieldDeveloperName, leadFieldValue);
            }
        }
        lead.Contact__c = leadWrapper.contactId;
        lead.RecordTypeId = leadWrapper.leadRecordTypeId;
        lead.Description = leadWrapper.description;
        lead.Project__c = leadWrapper.projectId;
        lead.FirstName = leadWrapper.leadFirstName;
        lead.LastName = leadWrapper.leadLastName;
        lead.Lead_Item_of_Interest__c = leadWrapper.leadItemOfInterest;

        insert lead;

        delete [SELECT Id FROM CampaignMember WHERE ContactId = :leadWrapper.contactId AND CampaignId = :leadWrapper.campaignId];

        CampaignMember campaignMember = new CampaignMember();
        campaignMember.contactId = leadWrapper.contactId;
        campaignMember.leadId = lead.Id;
        campaignMember.campaignId = leadWrapper.campaignId;
        insert campaignMember;

        Task task = new Task();
        task.ActivityDate = System.today();
        task.Description = 'Lead created from Contact';
        task.Subject = 'Lead created from Contact';
        task.WhoId = leadWrapper.contactId;
        task.Lead__c = lead.Id;
        task.Status = 'Completed';

        insert task;


        return lead.Id;
    }

    public class LeadWrapper{
        @AuraEnabled public Id contactId {set;get;}
        @AuraEnabled public Id campaignId {set;get;}
        @AuraEnabled public Id projectId {set;get;}
        @AuraEnabled public Id leadRecordTypeId {set;get;}

        @AuraEnabled public String description {set;get;}
        @AuraEnabled public String leadItemOfInterest {set;get;}

        @AuraEnabled public String leadFirstName {set;get;}
        @AuraEnabled public String leadLastName {set;get;}
        public LeadWrapper(){

        }
    }
}