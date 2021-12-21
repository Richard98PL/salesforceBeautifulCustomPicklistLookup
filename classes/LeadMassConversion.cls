public with sharing class LeadMassConversion {
    Campaign c;
    sObject so;
    ApexPages.Standardcontroller s;
   
    // LeadId => Fonecta_ID__c
    Map<Id, String> lFonMap=new Map<Id, String>();
    // leads that we were not able to convert in first round -> save it for second round
    Map<Id, String> lFonMap2=new Map<Id, String>();
    // Leads having Fonecta Id and lead name is [ei käytettävissa] or [not provided]
    Map<Id, String> lFonMapUnkn=new Map<Id, String>();
    // Accounts with FonectaID, fonId -> account
    Map<String,Account> accsFon=new Map<String,Account>();
    Map<String,Set<String>> fonIdNameSet=new Map<String,Set<String>>();
	
	// EDIT 20.3.2012
   	List<String> names=new List<String>();

    // LeadId => D_B_ID__c
   	Map<Id, String> lDBMap=new Map<Id, String>();
   	// leads that we were not able to convert in first round -> save it for second round
   	Map<Id, String> lDBMap2=new Map<Id, String>();
   	// leads having DB Id and lead name is [ei käytettävissa] or [not provided]
    Map<Id, String> lDBMapUnkn=new Map<Id, String>();
   	// Accounts with D&B ID
    Map<String,Account> accsDB=new Map<String,Account>();
    Map<String,Set<String>> dbIdNameSet=new Map<String,Set<String>>();
    
   	 // LeadId => AccountID__c
    Map<Id,String> 	lAccMap= new Map<Id,String>();
    // LeadId => AccountID__c
    Map<Id,String> 	lAccMap2= new Map<Id,String>();
    // Leads that have Account Id and name is [ei käytettävissa] or [not provided]
    Map<Id, String> lAccMapUnkn=new Map<Id, String>();
    Map<String,Set<String>> accIdNameSet=new Map<String,Set<String>>();
    // All found leads leadId => lead
    Map<Id,Lead> 	leads=new Map<Id,Lead>();
   	// Accounts with AccountID__c
    Map<Id,Account> accsA=new Map<Id,Account>();
	Set<Id> changeLeadNames=new Set<Id>();
 	
 	// -------------------------------------------------------------------------
    // Contacts found (FonectaID)
    // EDIT 20.3.2012
    //Set<Contact> conFon=new Set<Contact>();
    Map<String,Contact> conFon=new Map<String,Contact>();
    // Contacts found (D&B ID)
    // EDIT 20.3.2012
    //Set<Contact> conDB=new Set<Contact>();
    Map<String,Contact> conDB=new Map<String,Contact>();
    // Contacts found (AccountID__c)
    // EDIT 20.3.2012
    //Set<Contact> conAcc=new Set<Contact>();
    Map<String,Contact> conAcc=new Map<String,Contact>();
    // muuttuja Lead Conversion -painikkeen näkyvyyden määrittelemiseen
 	boolean piiloita;
 	Set<Id> profilesNotAbleToConvert = new Set<Id>();
 	
 	
    Set<String> leadsUnknown = LeadMassConversionUnkn__c.getAll().keySet();
    String unkn='Unknown';
    
    String leadConvertStatus;
    public LeadMassConversion (ApexPages.Standardcontroller std){
        s = std;
        so = s.getRecord();
        c = (Campaign)s.getRecord();
        
        for(Profile p : [select Id from Profile where Name = 'YIT Partner - Teleprospecting']){
        	profilesNotAbleToConvert.add(p.Id);
        }
        
        piiloita=false;
        for(Lead liidi:[select Id, Name, Status, Company, Rating__c, 
                        Has_open_opportunities__c, Last_campaign_response__c,
                        Title, Last_deal_won__c,OwnerId, SalesLead_ID__c,
                        Fonecta_ID__c,D_B_ID__c, AccountID__c, Owner.ProfileId
                        from Lead
                        where IsConverted = false
                        and ((Status = 'Converted')or(Status = 'No actions'))
                        and ((Fonecta_ID__c!='' and Fonecta_ID__c!= null) 
                              or (D_B_ID__c!='' and D_B_ID__c!=null)
                              or (AccountID__c!='' and AccountID__c!=null)
                        )        
                        and OwnerId IN(
                                        select Id 
                                        from User 
                                        where Ota_huomioon__c=true
                            )
                        and Id IN(
                                select LeadId
                                from CampaignMember 
                                where CampaignId = :c.Id 
                            )
                        order by LastName limit 500]){
			// put leads to Map, one Fonecta Id can have multiple leads, because leadId is key
            if(liidi.Fonecta_ID__c!=null && liidi.Fonecta_ID__c!='') {
            	// if lead name is [not provided] or [e käytettävissä], save it to different map
            	// these leads are converted first
            	if(leadsUnknown.contains(liidi.Name)){
            		lFonMapUnkn.put(liidi.Id,liidi.Fonecta_ID__c);
            		// we are going to change lead name to 'Unknown'
            		changeLeadNames.add(liidi.Id);
            	}
            	// otherwise lead is put to lFonMap map
            	else lFonMap.put(liidi.Id,liidi.Fonecta_ID__c);
            }
            else if(liidi.AccountID__c!=null && liidi.AccountID__c!='') {
            	Id validId;
				try {
					// this is done to check, that provided Account Id is valid
					validId = liidi.AccountID__c;
					// same as before: if lead name is [not provided] or [ei käytettävissä], put it to different map
					if(leadsUnknown.contains(liidi.Name)){
						lAccMapUnkn.put(liidi.Id,liidi.AccountID__c);
						changeLeadNames.add(liidi.Id);
					}
					else lAccMap.put(liidi.Id,liidi.AccountID__c);
				}
				catch (Exception ex) {
					System.debug('------------------- AccountID-field hasn\'t got a valid ID');
				}
            }
            else if(liidi.D_B_ID__c!=null && liidi.D_B_ID__c!=''){
            	if(leadsUnknown.contains(liidi.Name)){
            		lDBMapUnkn.put(liidi.Id,liidi.D_B_ID__c);
            		changeLeadNames.add(liidi.Id);
            	}
            	else lDBMap.put(liidi.Id,liidi.D_B_ID__c);
            }
            // finally, put lead information to a list, that contains all leads
            leads.put(liidi.Id,liidi);
        }
    }
    public pageReference showInfo(){
        //EDIT 10.09.2012: Not calculating leads without name Integer convert=lAccMap.size()+lFonMap.size()+lDBMap.size();
        Integer convert=lAccMap.size()+lFonMap.size()+lDBMap.size()+lAccMapUnkn.size()+lFonMapUnkn.size()+lDBMapUnkn.size();
        ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.INFO, Label.LeadMassConvert_liidia_muunnettavana+' '+convert);
        ApexPages.addMessage(myMsg);
        if(convert>0)piiloita=false;else piiloita=true;
        return null;
    }

    public pageReference massConversion(){
        List<Database.LeadConvert> lc=new List<Database.LeadConvert>();
        List<Database.LeadConvert> lc2=new List<Database.LeadConvert>();
        leadConvertStatus=[Select Id, MasterLabel from LeadStatus where IsConverted=true limit 1].MasterLabel;
        
        // EDIT 12.11.2012
        // We are not going to update ContactLead upon Mass Conversion
        // We assume, that if ContactLead is created and added to Campaign, its Description is written to Campaign Member description
        Utils.isLeadMassConversion = true;
        
        List<Lead> changeLeads=new List<Lead>();
        // Lets change lead name from [ei käytettävissä] or [not provided] to 'Unknown'
        for(Id leadId:changeLeadNames){
        	Lead l=leads.get(leadId);
        	l.FirstName='';
        	l.LastName=unkn;
        	changeLeads.add(l);
        }
        try{
       		update changeLeads;
        }
        catch(DmlException e){
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, 'Virhe [ei käytettävissä]-liidien tietojen päivityksessä ');
            ApexPages.addMessage(myMsg);
            return null;
        }
        // now lets update leads-list. We want to find information about leads, that we just updated
        for(Lead l:[select Id, Name, Status, Company, Rating__c, Owner.ProfileId,
                        Has_open_opportunities__c, Last_campaign_response__c,
                        Title, Last_deal_won__c,OwnerId, SalesLead_ID__c,
                        Fonecta_ID__c,D_B_ID__c, AccountID__c
                        from Lead
                        where Id IN:changeLeads]){
        	leads.put(l.id,l);
        }
        
        // EDIT 20.3.2012
        for(Lead l :leads.values()){
        	names.add(l.Name);
        }
        
        // EDIT 24.20.2012
        List<String> fonIDStrings = new List<String>();
        fonIDStrings.addAll(lFonMapUnkn.values());
        fonIDStrings.addAll(lFonMap.values());
        
        List<String> accIdStrings = new List<String>();
        accIdStrings.addAll(lAccMapUnkn.values());
        accIdStrings.addAll(lAccMap.values());
        
        List<String> dbIDStrings = new List<String>();
        dbIDStrings.addAll(lDBMapUnkn.values());
        dbIDStrings.addAll(lDBMap.values());
        
        for(Account a: [select Id,Name,Fonecta_ID__c,D_B_ID__c,
        						(select Id,Name,AccountId from Contacts where Name IN :names)
            				from Account
            				where Fonecta_ID__c IN :fonIDStrings
            				or Id IN :accIdStrings
            				or D_B_ID__c IN :dbIDStrings]){
            if(a.Fonecta_ID__c != null){
            	accsFon.put(a.Fonecta_ID__c,a);
            	for(Contact c: a.Contacts){
		            conFon.put(c.AccountId+c.Name,c);
		        }
            }
            
            if(a.D_B_ID__c != null){
            	accsDB.put(a.D_B_ID__c,a);
            	for(Contact c : a.Contacts){         	
            		conDB.put(c.AccountId+c.Name,c);
                }
            }
            accsA.put(a.Id,a);
            for(Contact c : a.Contacts){
            	conAcc.put(c.AccountId+c.Name,c);
            }
        }

        // Leads that have Fonecta Id and name is now 'Unknown'
        if(lFonMapUnkn.size()>0 || lFonMap.size()>0){
        	Map<Id, String> lcFonecta = new Map<Id, String>();
        	lcFonecta.putAll(lFonMapUnkn);
        	lcFonecta.putAll(lFonMap);
        	List<Database.LeadConvert> lcFon=getFonectaLeadConverts(lcFonecta);
            if(lcFon.size()>0)lc.addAll(lcFon);
        }
		// Leads having Account Id and name is now Unknown
        if(lAccMapUnkn.size()>0 || lAccMap.size()>0){
        	Map<Id,String> lcAccounts = new Map<Id,String>();
        	lcAccounts.putAll(lAccMapUnkn);
        	lcAccounts.putAll(lAccMap);
        	List<Database.LeadConvert> lcAcc=getAccIDLeadConverts(lcAccounts);
            if(lcAcc.size()>0)lc.addAll(lcAcc);
        }
        // Leads having DB Id and name is now Unknown
        if(lDBMapUnkn.size()>0 || lDBMap.size()>0){
        	Map<Id,String> ldbLeadsMap = new Map<Id,String>();
        	ldbLeadsMap.putAll(lDBMapUnkn);
        	ldbLeadsMap.putAll(lDBMap);
        	List<Database.LeadConvert> lcDB=getDBLeadConverts(ldbLeadsMap);
            if(lcDB.size()>0)lc.addAll(lcDB);
        }
        
        Integer indeksi=0;
   		// now let's convert leads for the first time
   		system.debug('--------------- lead converts : '+lc);
        Database.LeadConvertResult[] lcr = Database.convertLead(lc,false);
        Map<Id,Id> kontaktit=new Map<Id,Id>();
        for (Integer i=0; i<lcr.size(); i++) {
            if (lcr[i].isSuccess()){
                kontaktit.put(lcr[i].getContactId(),lcr[i].getAccountId()); 
            	indeksi++;
            }
        }
        
        // EDIT 24.20.2012
        fonIDStrings = new List<String>();
        fonIDStrings.addAll(lFonMap2.values());

        accIdStrings = new List<String>();
        accIdStrings.addAll(lAccMap2.values());

        dbIDStrings = new List<String>();
        dbIDStrings.addAll(lDBMap2.values());
        
        for(Account a: [select Id,Name,Fonecta_ID__c,D_B_ID__c,
        						(select Id,Name,AccountId from Contacts where Name IN :names)
            				from Account
            				where Fonecta_ID__c IN :fonIDStrings
            				or Id IN :accIdStrings
            				or D_B_ID__c IN :dbIDStrings]){
            if(a.Fonecta_ID__c != null){
            	accsFon.put(a.Fonecta_ID__c,a);
            	for(Contact c: a.Contacts){
		            conFon.put(c.AccountId+c.Name,c);
		        }
            }
            
            if(a.D_B_ID__c != null){
            	accsDB.put(a.D_B_ID__c,a);
            	for(Contact c : a.Contacts){         	
            		conDB.put(c.AccountId+c.Name,c);
                }
            }
            accsA.put(a.Id,a);
            for(Contact c : a.Contacts){
            	conAcc.put(c.AccountId+c.Name,c);
            }
            
        }
        
        // if there is leads, that we were not able to convert on first round, do it now
        if(lFonMap2.size()>0){
            List<Database.LeadConvert> lcFon=getFonectaLeadConverts(lFonMap2);
            if(lcFon.size()>0)lc2.addAll(lcFon);
        }
        // same story with leads having Account Id
		if(lAccMap2.size()>0){
            List<Database.LeadConvert> lcAcc=getAccIDLeadConverts(lAccMap2);
            if(lcAcc.size()>0)lc2.addAll(lcAcc);
        }
        if(lDBMap2.size()>0){
            List<Database.LeadConvert> lcDB=getDBLeadConverts(lDBMap2);
           	if(lcDB.size()>0)lc2.addAll(lcDB);
           
        }
		// Try converting second set of leads
		system.debug('--------------- lead converts2 : '+lc2);
        Database.LeadConvertResult[] lcr2 = Database.convertLead(lc2,false);       
        for (Integer i=0; i<lcr2.size(); i++) {
            if (lcr2[i].isSuccess()){
                kontaktit.put(lcr2[i].getContactId(),lcr2[i].getAccountId()); 
            	indeksi++;
            }
        }
        
        List<CampaignMember> memberit=new List<CampaignMember>();
        
		// Updating camplaign members
        for(CampaignMember cm:[SELECT Id,ContactId,Account__c
                               FROM CampaignMember
                               WHERE ContactId IN :kontaktit.keySet()
                               AND CampaignId=:c.Id]){
            cm.Account__c=kontaktit.get(cm.ContactId);
            memberit.add(cm);
        }
        //System.debug('...........................memberit.size'+memberit.size());
        try{
		// Invalidi "000" valuuttaa aiheuttaa täällä  virheen. Case salesforcelle mikä se on, ei voi päivittää dataloaderilla
            update memberit;
        }
        catch(DmlException e){
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, 'Virhe tietojen päivityksessä: '+e.getMessage());
            ApexPages.addMessage(myMsg);
            return null;
        }
        integer summa = memberit.size();
        //integer summa=lcr.size()+lcr2.size();
        ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.CONFIRM, summa+' '+Label.LeadMassConvert_liidia_muunnettu);
        ApexPages.addMessage(myMsg);
        piiloita=true;
        pageReference p=null;
        return p;
    }
    
    public pageReference previousPage(){
        pageReference p = new pageReference('/'+ApexPages.currentPage().getParameters().get('id')) ;
        return p;
    }
    private List<Database.LeadConvert> getFonectaLeadConverts(Map<Id, String> fonMap) {
    	List<Database.LeadConvert> lc=new List<Database.LeadConvert>();
		// try to make leadconvert items from found leads
        for(String s:fonMap.keySet()){
        	Account acc=null;
        	Contact cont=null;
        	// Let's fetch lead information
        	Lead l=leads.get(s);
        	// Next find lead names that we have converted to certain Fonecta Id
        	// this is done to prevent making duplicates
        	Set<String> namesToFonId=fonIdNameSet.get(l.Fonecta_ID__c);
        	if(namesToFonId==null)namesToFonId=new Set<String>();

        	// Check if account was found, that has the same Fonecta Id
        	if(accsFon.get(l.Fonecta_ID__c)!=null){
        		acc=accsFon.get(l.Fonecta_ID__c);
        		// Check if we have contact under this account, that has same name as lead   
        		if(conFon.get(acc.Id+l.Name)!=null)cont=conFon.get(acc.Id+l.Name);
		        // There is a contact -> convert to this account and contact
		        if(cont!=null){
		        	//System.debug('fon kontakti olemassa '+cont.Name+', '+acc.Fonecta_ID__c);
		        	Database.Leadconvert lcItem=new Database.Leadconvert();
        			lcItem.setAccountId(acc.Id);
        			lcItem.setLeadId(l.Id);
        			lcItem.setContactId(cont.Id);
       				lcItem.setConvertedStatus(leadConvertStatus);
            		lcItem.setDoNotCreateOpportunity(true);
            		lc.add(lcItem);
		        }
		        // There is no contact, let's check if we have made a leadconvert to a lead having the same name
		        // as this lead has. We use Fonecta Id to fetch names that we have converted/are going to convert
		        // this round
		        else if(!namesToFonId.contains(l.Name)){
		        	//System.debug('-----------------fon kontakti ei olemassa, luodaan uusi '+l.Name+', '+acc.Fonecta_ID__c);
		        	Database.Leadconvert lcItem=new Database.Leadconvert();
		        	// EDIT 20.01.2012 Check user profile. 
		        	// If user of the lead has profile, that has no rights to create contacts or leads, 
		        	// put current user as owner of the contact/account
		        	if(profilesNotAbleToConvert.contains(l.Owner.ProfileId))lcItem.setOwnerId(UserInfo.getUserId());
        			lcItem.setAccountId(acc.Id);
        			lcItem.setLeadId(l.Id);
       				lcItem.setConvertedStatus(leadConvertStatus);
            		lcItem.setDoNotCreateOpportunity(true);
            		lc.add(lcItem);
            		namesToFonId.add(l.Name);
        			fonIdNameSet.put(l.Fonecta_ID__c,namesToFonId);
		        }
		        // there is no contact and we have made leadconvert item, that has same name as current lead
		        // put it to a map to convet it on second round
		        else {
		        	//System.debug('--------------------fon kontaktia ei ole, mutta me ollaan tehty leadConvert saman nimiselle liidille '+l.Name+', '+acc.Fonecta_ID__c);
		        	lFonMap2.put(s,fonMap.get(s));
		        }
        	}
        	// there is no account, that has the same fonecta Id -> 
        	// let's check that we have not already ade an leadconvert item for a lead that has same
        	// fonecta id
        	else if(fonIdNameSet.get(l.Fonecta_ID__c)==null){
        		//System.debug('--------------------fon else Accounttia ei löydy -> tehdään uusi Account ja Contact '+l.Name+', '+l.Fonecta_ID__c); 	
        		Database.Leadconvert lcItem=new Database.Leadconvert();
				// EDIT 20.1.2012 
				// check lead owner profile
            	if(profilesNotAbleToConvert.contains(l.Owner.ProfileId))lcItem.setOwnerId(UserInfo.getUserId());
        		lcItem.setLeadId(l.Id);
            	lcItem.setConvertedStatus(leadConvertStatus);
            	lcItem.setDoNotCreateOpportunity(true);
            	lc.add(lcItem);
            	namesToFonId.add(l.Name);
        		fonIdNameSet.put(l.Fonecta_ID__c,namesToFonId);
        	}
        	// we have made a leadconvert item for a lead having the same Fonecta Id -> not making a duplicate account
        	else {
        		//System.debug('--------------------we have made a leadconvert item for a lead having the same Fonecta Id -> not making a duplicate account '+l.Name+', '+l.Fonecta_ID__c);
		        lFonMap2.put(s,fonMap.get(s));
        	}
        }
    	return lc;
    }
    private List<Database.LeadConvert> getAccIDLeadConverts(Map<Id, String> accMap) {
    	List<Database.LeadConvert> lc=new List<Database.LeadConvert>();
    	//These leads have an account id -> let's find all these accounts
        for(String s:accMap.keySet()){
        	Account acc=null;
        	Contact cont=null;
        	// Fetch lead information
        	Lead l=leads.get(s);
        	// Find all the names of leads we have made a leadconvert item
        	// using account Id as key
        	Set<String> namesToAccId=accIdNameSet.get(l.AccountID__c);
        	if(namesToAccId==null)namesToAccId=new Set<String>();

        	// We should have found accounts for all the provided account Ids
        	// otherwise lead is not converted, because it has potentially wrong information
        	if(accsA.get(l.AccountID__c)!=null){
        		acc=accsA.get(l.AccountID__c);
        		// let's check if we can find a contact having the same name as our lead
        		if(conAcc.get(acc.Id+l.Name)!=null)cont=conAcc.get(acc.Id+l.Name);
		        // If contact was found, convert it to this account and contact
		        if(cont!=null){
		        	//System.debug('acc kontakti olemassa '+cont.Name+', '+acc.Id);
		        	Database.Leadconvert lcItem=new Database.Leadconvert();
        			lcItem.setAccountId(acc.Id);
        			lcItem.setLeadId(l.Id);
        			lcItem.setContactId(cont.Id);
       				lcItem.setConvertedStatus(leadConvertStatus);
            		lcItem.setDoNotCreateOpportunity(true);
            		lc.add(lcItem);
		        }
		        // There is no contact -> check if we have already made a leadconvert item for
		        // a lead having the same name as our lead has
		        else if(!namesToAccId.contains(l.Name)){
		        	//System.debug('-----------------acc kontakti ei olemassa, luodaan uusi '+l.Name+', '+acc.Id);
		        	Database.Leadconvert lcItem=new Database.Leadconvert();
		        	// EDIT 20.1.2012 
		        	if(profilesNotAbleToConvert.contains(l.Owner.ProfileId))lcItem.setOwnerId(UserInfo.getUserId());
        			lcItem.setAccountId(acc.Id);
        			lcItem.setLeadId(l.Id);
       				lcItem.setConvertedStatus(leadConvertStatus);
            		lcItem.setDoNotCreateOpportunity(true);
            		lc.add(lcItem);
            		namesToAccId.add(l.Name);
        			accIdNameSet.put(l.AccountID__c,namesToAccId);
		        }
		        // there is no contact, but we have made a leadconvert item for a lead that has same name as this lead
		        // convert it on second round
		        else {
		        	//System.debug('--------------------acc kontaktia ei ole, mutta me ollaan tehty leadConvert saman nimiselle liidille '+l.Name+', '+acc.Id);
		        	lAccMap2.put(s,accMap.get(s));
		        }
        	}
        }
        return lc;
    }
    private List<Database.LeadConvert> getDBLeadConverts(Map<Id, String> dbMap) {
    	List<Database.LeadConvert> lc=new List<Database.LeadConvert>();
        for(String s:dbMap.keySet()){
        	Account acc=null;
        	Contact cont=null;
        	// get lead data
        	Lead l=leads.get(s);
        	// Find all the names of leads we have made a leadconvert item
        	// using DB Id as key
        	Set<String> namesToDBId=dbIdNameSet.get(l.D_B_ID__c);
        	if(namesToDBId==null)namesToDBId=new Set<String>();
        	
        	// Check if account was found having the same DB id as our lead has
        	if(accsDB.get(l.D_B_ID__c)!=null){
        		acc=accsDB.get(l.D_B_ID__c);
        		// Check if we can find a contact
        		if(conDB.get(acc.Id+l.Name)!=null)cont=conDB.get(acc.Id+l.Name);
		        // There is a contact -> convert it to this account and contact
		        if(cont!=null){
		        	//System.debug('db kontakti olemassa '+cont.Name+', '+l.D_B_ID__c);
		        	Database.Leadconvert lcItem=new Database.Leadconvert();
        			lcItem.setAccountId(acc.Id);
        			lcItem.setLeadId(l.Id);
        			lcItem.setContactId(cont.Id);
       				lcItem.setConvertedStatus(leadConvertStatus);
            		lcItem.setDoNotCreateOpportunity(true);
            		lc.add(lcItem);
		        }
		        // There is no contact -> check if w have made a leadconvert to a lead havng the same name
		        // as current lead has
		        else if(!namesToDBId.contains(l.Name)){
		        	//System.debug('--------------------db !namesToDBId.contains(l.Name) '+l.Name+', '+l.D_B_ID__c); 	
        		
		        	Database.Leadconvert lcItem=new Database.Leadconvert();
		        	// EDIT 20.1.2012 
		        	if(profilesNotAbleToConvert.contains(l.Owner.ProfileId))lcItem.setOwnerId(UserInfo.getUserId());
        			lcItem.setAccountId(acc.Id);
        			lcItem.setLeadId(l.Id);
       				lcItem.setConvertedStatus(leadConvertStatus);
            		lcItem.setDoNotCreateOpportunity(true);
            		lc.add(lcItem);
            		namesToDBId.add(l.Name);
        			dbIdNameSet.put(l.D_B_ID__c,namesToDBId);
		        }
		        // we have already made a leadconvert item for lead that has same name as current lead
		        else {
		        	//System.debug('--------------------db accsDB.get(l.D_B_ID__c)!=null else  '+l.Name+', '+l.D_B_ID__c);
		        	lDBMap2.put(s,dbMap.get(s));
		        }
        	}
        	// there is no matching account -> check if we have made leadconvert item for this account
        	else if(dbIdNameSet.get(l.D_B_ID__c)==null){
        		//System.debug('--------------------db else Accounttia ei löydy -> tehdään uusi Account ja Contact '+l.Name+', '+l.D_B_ID__c); 	
        		Database.Leadconvert lcItem=new Database.Leadconvert();
        		// EDIT 20.1.2012 
		        if(profilesNotAbleToConvert.contains(l.Owner.ProfileId))lcItem.setOwnerId(UserInfo.getUserId());
            	lcItem.setLeadId(l.Id);
            	lcItem.setConvertedStatus(leadConvertStatus);
            	lcItem.setDoNotCreateOpportunity(true);
            	lc.add(lcItem);
            	namesToDBId.add(l.Name);
        		dbIdNameSet.put(l.D_B_ID__c,namesToDBId);
        	}
        	// we have made a leadconvert item for a lead that has same db id -> not making duplicate account
        	else {
        		//System.debug('--------------------db kontaktia ja accounttia ei ole, mutta me ollaan tehty leadConvert saman nimiselle liidille '+l.Name+', '+l.D_B_ID__c);
		        lDBMap2.put(s,dbMap.get(s));
        	}
        }
        return lc;
    }

    public boolean getPiiloita(){
        return piiloita;
    }
}