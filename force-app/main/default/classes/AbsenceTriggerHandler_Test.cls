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
private class AbsenceTriggerHandler_Test {

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
        employee.ERP_Resource_No__c = 'APU';
        employee.flair__Entity__c = entity.Id;
        insert employee;

        flair__Absence_Category__c absenceCategory = new flair__Absence_Category__c();
        absenceCategory.Name = 'Paid Leave';
        absenceCategory.Absence_Code__c = 'VACATION';
        insert absenceCategory;

        flair__Employee_Absence_Category__c employeeAbsenceCategory = new flair__Employee_Absence_Category__c();
        employeeAbsenceCategory.flair__Absence_Category__c = absenceCategory.Id;
        employeeAbsenceCategory.flair__Employee__c = employee.Id;
        insert employeeAbsenceCategory;

        flair__Absence__c absence = new flair__Absence__c();
        absence.flair__Employee_Absence_Category__c = employeeAbsenceCategory.Id;
        absence.flair__Approval_Status__c = 'APPROVED';
        absence.flair__Start_Date__c = Date.newInstance(2025, 02, 17);
        absence.flair__End_Date__c = Date.newInstance(2025, 02, 17);
        absence.flair__Start_Time__c = Time.newInstance(00, 00, 00, 00);
        absence.flair__End_Time__c = Time.newInstance(23, 59, 00, 00);
        insert absence;

        flair__Absence_Day__c absenceDay = new flair__Absence_Day__c();
        absenceDay.flair__Absence__c = absence.Id;
        absenceDay.flair__Day__c = Date.newInstance(2025, 02, 17);
        absenceDay.flair__Workload_Amount_in_Minutes__c = 480;
        absenceDay.flair__Amount__c = 1;
        absenceDay.flair__Upserting_Key__c = '2025-02-17';
        absenceDay.Migration_ID__c = '1233545';
        absenceDay.flair__Employee__c = employee.Id;
        insert absenceDay;
    }

    @isTest
    static void test_update() {
        flair__Absence__c absence = [SELECT flair__Approval_Status__c, flair__End_Date__c FROM flair__Absence__c WHERE flair__Approval_Status__c = 'APPROVED' LIMIT 1];
        absence.flair__End_Date__c = Date.newInstance(2025, 02, 18);

        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_createEmployeeAbscence_Success');
            mock.setStatusCode(201);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            update absence;
            Test.stopTest();
            Date endDate = Date.newInstance(2025, 02, 18);
            Assert.areEqual(1, [SELECT flair__Approval_Status__c, flair__End_Date__c FROM flair__Absence__c WHERE flair__End_Date__c = :endDate].size(), 'Absence not updated');
        }
    }

    @isTest
    static void test_CreateRelatedEmployeeAbsencesInMSBC() {
        flair__Absence__c absence = [SELECT Id FROM flair__Absence__c WHERE flair__Approval_Status__c = 'APPROVED' LIMIT 1];

        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_createEmployeeAbscence_Success');
            mock.setStatusCode(201);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            
            Test.startTest();
            System.enqueueJob(new AbsenceTriggerHandler.CreateRelatedEmployeeAbsencesInMSBC(new Set<Id>{absence.Id}));
            Test.stopTest();
        }
    }

    @isTest
    static void test_delete() {
        flair__Absence__c absence = [SELECT flair__Approval_Status__c, flair__End_Date__c FROM flair__Absence__c WHERE flair__Approval_Status__c = 'APPROVED' LIMIT 1];
        absence.flair__End_Date__c = Date.newInstance(2025, 02, 18);
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_createEmployeeAbscence_Success');
            mock.setStatusCode(201);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            delete absence;
            Test.stopTest();
            Assert.areEqual(0, [SELECT Id, Migration_ID__c FROM flair__Absence_Day__c].size(), 'Absence day not deleted');
        }
    }
}