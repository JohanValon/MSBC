/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class TimeEntries_ScheduleBatch_Test {

    @TestSetup
    static void setup(){
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User admin = new User(
            FirstName = 'Dummy',
            LastName = 'User',
            Alias = 'duser',
            Email = 'dummyuser@example.com',
            Username = 'dummyuser' + System.currentTimeMillis() + '@example.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        insert admin;

        flair__Entity__c entity = new flair__Entity__c();
        entity.Name = 'Con4Mare GmbH & Cie. KG';
        insert entity;

        System.runAs(admin){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getAvailableCompanies_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            MSBCAPI.setupAPI();
            Test.stopTest();
            Assert.areEqual(true, [SELECT Name, Is_MSBC_Synched__c, flair__Migration_ID__c FROM flair__Entity__c WHERE Is_MSBC_Synched__c = true].size() > 0, 'Entity not synched');
        }

        flair__Employee__c employee = new flair__Employee__c(); 
        employee.Name = 'John Doe';
        employee.Company_Personnel_Number__c = 'CM-00000';
        employee.flair__Entity__c = entity.Id;
        insert employee;
    }

    @isTest
    static void test_batch() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getHeaders_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            Database.executebatch(new TimeEntries_ScheduleBatch());
            Test.stopTest();
            Assert.areEqual(5, [SELECT Id FROM flair__Time_Entry__c WHERE flair__Approval_Status__c = 'APPROVED'].size(), 'Time entries not created');
            Assert.areEqual(5, [SELECT Id FROM flair__Time_Entry_Break__c WHERE flair__Total_Break_Period_in_Hours__c != 0].size(), 'Time entry breaks not created');
        }
    }

    @isTest
    static void test_batch_mark_records_to_delete() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        Id employeeId = [SELECT Id FROM flair__Employee__c WHERE Company_Personnel_Number__c = 'CM-00000' LIMIT 1].Id;

        System.runAs(contextuser){

            StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'MSBCAPI_getHeaders_Success'];
            String response = sr.Body.toString();
            response = response.replace('"date":', '"xdate":');
            response = response.replace('"@odata.context":', '"odataContext":');
            response = response.replace('"@odata.etag":', '"odataEtag":');
            MSBCAPI.PostedZDEHeaders postedHeaders = (MSBCAPI.PostedZDEHeaders) JSON.deserialize(response, MSBCAPI.PostedZDEHeaders.class);

            flair__Time_Entry__c[] timeEntries = new List<flair__Time_Entry__c>();
            for( MSBCAPI.Header header : postedHeaders.value ) {
                flair__Time_Entry__c timeEntry = new flair__Time_Entry__c();
                timeEntry.flair__Employee__c = employeeId;
                timeEntry.flair__Migration_ID__c = header.id;
                timeEntry.flair__Start_Datetime__c = Datetime.valueOf(header.xdate + ' ' + header.fromTime);
                timeEntry.flair__End_Datetime__c =  Datetime.valueOf(header.xdate + ' ' + header.toTime);
                timeEntry.odata_etag__c = header.odataEtag;
                timeEntry.flair__Approval_Status__c = 'APPROVED';
                timeEntries.add(timeEntry);
            }
            insert timeEntries;

            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getHeaders_Success_Update');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            Database.executebatch(new TimeEntries_ScheduleBatch());
            Test.stopTest();
            Assert.areEqual(5, [SELECT Id FROM flair__Time_Entry__c WHERE To_Delete__c = true].size(), 'Time entries has not been marked as to delete');
            Assert.areEqual(5, [SELECT Id FROM flair__Time_Entry__c WHERE To_Delete__c = false].size(), 'Time entries has not been updated');
        }
    }

    @isTest
    static void test_schedule() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getHeaders_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            TimeEntries_ScheduleBatch.start();
            Test.stopTest();
            CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE CronExpression = '0 0 1 ? * *'];
            Datetime today = Datetime.now().addDays(1);
            System.assertEquals(today.date(), ct.NextFireTime.date(), 'Job not scheduled tomorrow');
            System.assertEquals(Datetime.newInstance(today.year(), today.month(), today.day(), 1, 0, 0).time(), ct.NextFireTime.time(), 'Job not scheduled tomorrow at 1:AM');
        } 
    }
}