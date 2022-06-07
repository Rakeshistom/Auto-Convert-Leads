@isTest
public with sharing class LeadConvert_TEST {
    @TestSetup
    static void prepEnvironment(){
        Account testAccount = new Account(Name = 'Test Inc');
        insert testAccount;
        // Account testFoundation = new Account(Name = 'Foundation');
        // insert testFoundation;

        Contact testContact = new Contact(
            FirstName = 'Test', 
            LastName = 'Tester',
            AccountId = testAccount.Id,
            Email = 'test@example.com',
            MailingStreet = 'Testerstreet 1',
            MailingPostalCode = 'TEST',
            MailingCity = 'TestCity',
            MailingCountry = 'TestCountry');
        insert testContact;

        

        // Contact testFoundationContact = new Contact(
        //     FirstName = 'Found', 
        //     LastName = 'ation',
        //     AccountId = testInc.Id,
        //     Email = 'foundation@example.com',
        //     MailingStreet = 'Foundationstreet 1',
        //     MailingPostalCode = 'TEST',
        //     MailingCity = 'TestCity',
        //     MailingCountry = 'TestCountry');
        // insert testIncContact;
    }

    @IsTest
    static void leadConversionWithDuplicatesAndDeduplicationOn(){
        Contact testContact = [SELECT Id, FirstName, LastName, Email, MailingStreet, MailingCity, MailingPostalCode, MailingCountry FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Inc'];
        Lead testLead = new Lead(
            FirstName = testContact.FirstName, 
            LastName = testContact.LastName,
            Company = testAccount.Name,
            Email = testContact.Email,
            Street = testContact.MailingStreet,
            PostalCode = testContact.MailingPostalCode,
            City = testContact.MailingCity,
            Country = testContact.MailingCountry);
        insert testLead;

        List<LeadConvert.ConvertRequest> convertList = new List<LeadConvert.ConvertRequest>();
        LeadConvert.ConvertRequest cr = new LeadConvert.ConvertRequest();
        cr.LeadId = testLead.Id;
        cr.createOpportunity = false;
        cr.allowDeduplication = true;
        convertList.add(cr);

        Test.startTest();
        LeadConvert.ConvertResult[] results = LeadConvert.ConvertLeads(convertList);
        Test.stopTest();
        for(LeadConvert.ConvertResult result :results) {
            System.assertEquals(testContact.Id, result.contactId);
        }
        
    }

    @IsTest
    static void leadConversionWithDuplicatesAndDeduplicationOff(){
        Contact testContact = [SELECT Id, FirstName, LastName, Email, MailingStreet, MailingCity, MailingPostalCode, MailingCountry FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Inc'];
        Lead testLead = new Lead(
            FirstName = testContact.FirstName, 
            LastName = testContact.LastName,
            Company = testAccount.Name,
            Email = testContact.Email,
            Street = testContact.MailingStreet,
            PostalCode = testContact.MailingPostalCode,
            City = testContact.MailingCity,
            Country = testContact.MailingCountry);
        insert testLead;

        List<LeadConvert.ConvertRequest> convertList = new List<LeadConvert.ConvertRequest>();
        LeadConvert.ConvertRequest cr = new LeadConvert.ConvertRequest();
        cr.LeadId = testLead.Id;
        cr.createOpportunity = false;
        cr.allowDeduplication = false;
        convertList.add(cr);
        Boolean outcome = false;
        Test.startTest();
        Try {
            LeadConvert.ConvertResult[] results = LeadConvert.ConvertLeads(convertList);
            outcome = false;
        } catch(LeadConvert.LeadConversionException lce) {
            outcome = true;
        }
        Test.stopTest();
        System.assert(outcome, 'no exception occurred, should have fired on duplicate rules');
    }

    @IsTest
    static void leadConversionWithoutDuplicates(){
        Lead testLead = new Lead(
            FirstName = 'My unique firstname', 
            LastName = 'my unique lastname',
            Company = 'my unique company',
            Email = 'unique@email.com');
        insert testLead;

        List<LeadConvert.ConvertRequest> convertList = new List<LeadConvert.ConvertRequest>();
        LeadConvert.ConvertRequest cr = new LeadConvert.ConvertRequest();
        cr.LeadId = testLead.Id;
        cr.createOpportunity = false;
        cr.allowDeduplication = false;
        convertList.add(cr);

        Boolean outcome = false;
        Test.startTest();
        LeadConvert.ConvertResult[] results;
        Try {
            results = LeadConvert.ConvertLeads(convertList);
            outcome = true;
        } catch(LeadConvert.LeadConversionException lce) {
            System.debug('Error: '+lce.getMessage());
            outcome = false;
        }
        Test.stopTest();
        System.assert(outcome);
        Contact newContact = [SELECT Id FROM Contact WHERE Email = 'unique@email.com' LIMIT 1];
        for(LeadConvert.ConvertResult result :results) {
            System.assertEquals(newContact.Id, result.contactId);
        }
    }

    @IsTest
    static void leadConversionWithExistingContact(){
        Contact testContact = [SELECT Id, FirstName, LastName, Email, MailingStreet, MailingCity, MailingPostalCode, MailingCountry FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Inc'];
        Lead testLead = new Lead(
            FirstName = testContact.FirstName, 
            LastName = testContact.LastName,
            Company = testAccount.Name,
            Email = testContact.Email,
            Street = testContact.MailingStreet,
            PostalCode = testContact.MailingPostalCode,
            City = testContact.MailingCity,
            Country = testContact.MailingCountry);
        insert testLead;

        List<LeadConvert.ConvertRequest> convertList = new List<LeadConvert.ConvertRequest>();
        LeadConvert.ConvertRequest cr = new LeadConvert.ConvertRequest();
        cr.LeadId = testLead.Id;
        cr.contactId = testContact.Id;
        cr.createOpportunity = false;
        cr.allowDeduplication = false;
        convertList.add(cr);

        Boolean outcome = false;
        Test.startTest();
        LeadConvert.ConvertResult[] results;
        Try {
            results = LeadConvert.ConvertLeads(convertList);
            outcome = false;
        } catch(LeadConvert.LeadConversionException lce) {
            outcome = true;
        }
        Test.stopTest();
        for(LeadConvert.ConvertResult result : results) {
            System.assertEquals(testContact.Id, result.contactId);
        }
    }

    @IsTest
    static void testNrOfLeadsLimit(){
        List<LeadConvert.ConvertRequest> convertList = new List<LeadConvert.ConvertRequest>();
        List<Lead> leadList = new List<Lead>();
        
        for(Integer i = 0;i<60;i++) {
            Lead testLead = new Lead(
            FirstName = 'firstname'+i, 
            LastName = 'lastname'+i,
            Company = 'company'+i,
            Email = 'firstname'+i+'@email.com'
            );
            leadList.add(testLead);
        }
        for(Lead l : leadList) {
            LeadConvert.ConvertRequest cr = new LeadConvert.ConvertRequest();
            cr.leadId = l.Id;
            convertList.add(cr);
        }

        Test.startTest();
        Boolean outcome = false;
        try{
            LeadConvert.ConvertLeads(convertList);
            outcome = false;
        } catch(LeadConvert.LeadConversionException lce) {
            outcome = true;
        }
        Test.stopTest();
        System.assert(outcome);
    }
}
