/**
 * @author: Peter van der Meij <peter@findock.com>
 */
global with sharing class LeadConvert {
    global static LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];

    @InvocableMethod(label='Convert leads' description='Allows for leads to be converted, supports deduplication if needed.' category='Lead')
    global static ConvertResult[] ConvertLeads(List<ConvertRequest> convertList) {
        //to respect the DML limits lets limit the max number of records to 50; Every leadconvert can have 3 tries with duplication.
        if(convertList.size() > 50) {
            throw new LeadConversionException('To many records. A maximum of 50 leads is allowed at a time.');
        }
        List<Database.LeadConvert> conversionList = new List<Database.LeadConvert>();
        //since if the Contact ID is present, SF requires an Account ID as well. we'll check to see if the contact is popluated but the account id isn't. if so, we'll find the corresponding Account Id.
        Set<Id> contactIdsWithoutAccount = new Set<Id>();
        for(ConvertRequest cr : convertList) {            
            if(cr.contactId != null && cr.accountId == null) {
                contactIdsWithoutAccount.add(cr.contactId);
            }
        }
        Map<Id, Contact> contactMap = new Map<Id, Contact>([SELECT Id, AccountId FROM Contact WHERE Id IN :contactIdsWithoutAccount]);

        List<ConvertResult> results = new List<ConvertResult>();
        for(ConvertRequest cr : convertList) {            
            if(cr.contactId != null && contactMap.containsKey(cr.contactId)) {
                cr.accountId = contactMap.get(cr.contactId).AccountId;
            }
            //checks all done. Since leadconversions are DML operations anyway. There is no reason to not run them one by one.
            results.add(convertLead(cr));
        }
        return results;
    }

    private static ConvertResult convertLead(ConvertRequest cr) {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(cr.leadId);
        lc.setAccountId(cr.accountId);
        lc.setContactId(cr.contactId);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setDoNotCreateOpportunity(!cr.createOpportunity);
        Database.LeadConvertResult lcr = Database.convertLead(lc, false);
        if(!lcr.isSuccess()) {
            for(Database.Error error : lcr.getErrors()) {
                if(error instanceof Database.DuplicateError) {
                    Database.DuplicateError duplicateError = (Database.DuplicateError)error;
                    Datacloud.DuplicateResult duplicateResult = duplicateError.getDuplicateResult();
                    Datacloud.MatchResult[] matchResults = duplicateResult.getMatchResults();
                    String duplicateEntity;
                    for(Datacloud.MatchResult mr : matchResults) {
                        if(mr.getEntityType() == 'Account') {
                            Datacloud.MatchRecord[] matchRecords = mr.getMatchRecords();
                            Account duplicateAccount = (Account)matchRecords.get(0).getRecord();
                            cr.accountId = duplicateAccount.Id;
                            duplicateEntity = 'Account ('+cr.accountId+')';
                        } else if(mr.getEntityType() == 'Contact') {
                            Datacloud.MatchRecord[] matchRecords = mr.getMatchRecords();
                            Contact duplicateContact = (Contact)matchRecords.get(0).getRecord();
                            cr.contactId = duplicateContact.Id;
                            cr.accountId = duplicateContact.AccountId;
                            duplicateEntity = 'Contact ('+cr.contactId+')';
                        }
                    }
                    if(!cr.allowDeduplication) {
                        throw new LeadConversionException('Duplicate '+duplicateEntity+' found but deduplication is disallowed.');
                    }
                } else {
                    throw new LeadConversionException(error.getMessage());
                }
            }
            // System.debug('contact id set to '+cr.contactId);
            // System.debug('Account id set to '+cr.accountId);
            return convertLead(cr);
        } else {
            // System.debug('success!!!');
            // System.debug('account: '+lcr.getAccountId());
            // System.debug('contact: '+lcr.getContactId());
            // System.debug('lead:'+lcr.getLeadId());
        }
        //System.debug('completed leadconvert');
        ConvertResult result = new ConvertResult();
        result.contactId = lcr.getContactId();
        result.accountId = lcr.getAccountId();
        result.opportunityId = lcr.getOpportunityId();
        return result;
        
    }

    global class ConvertRequest {

        @invocableVariable(label='Lead ID' description='The record Id of the lead to convert' required=true)
        global Id leadId;

        @invocableVariable(label='Contact ID' description='The contact to merge this lead with')
        global Id contactId;

        @invocableVariable(label='Account ID' description='The account to link the new contact to')
        global Id accountId;

        @invocableVariable(label='Create Opportunity' description='If set to true, creates an opportunity, defaults to false.')
        global Boolean createOpportunity = false;

        @invocableVariable(label='Allow Deduplication' description='If set to true, Allows the lead convert to deduplicate against existing contacts. defaults to true')
        global Boolean allowDeduplication = true;

    }

    global class ConvertResult {
        
        @invocableVariable(label='Lead ID' description='The record Id of the converted lead')
        global Id leadId;

        @invocableVariable(label='Contact ID' description='The resulting Contact Id')
        global Id contactId;

        @invocableVariable(label='Account ID' description='The resulting Account Id')
        global Id accountId;

        @invocableVariable(label='Opportunity ID' description='The resulting Opportunity Id')
        global Id opportunityId;
    }

    global class LeadConversionException extends Exception {}

}
