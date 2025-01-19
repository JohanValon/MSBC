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
private class EmployeeAbsences_ScheduleBatch_Test {

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
        // flair__Absence_Type__c absenceType = new flair__Absence_Type__c();
        // absenceType.Name = 'Annual Leave';
        // insert absenceType;

        flair__Employee_Absence_Category__c employeeAbsenceCategory = new flair__Employee_Absence_Category__c();
        employeeAbsenceCategory.flair__Absence_Category__c = absenceCategory.Id;
        employeeAbsenceCategory.flair__Employee__c = employee.Id;
        insert employeeAbsenceCategory;

        flair__Absence__c absence = new flair__Absence__c();
        absence.flair__Employee_Absence_Category__c = employeeAbsenceCategory.Id;
        absence.flair__Start_Date__c = Date.today();
        absence.flair__Approval_Status__c = 'APPROVED';
        insert absence;

        // flair__Absence_Day__c absenceDay = new flair__Absence_Day__c();
        // absenceDay.flair__Absence__c = absence.Id;
        // absenceDay.flair__Workload_Amount_in_Minutes__c = 480;
        // insert absenceDay;

        // flair__Absence_Day__c absenceDay2 = new flair__Absence_Day__c();
        // absenceDay2.flair__Absence__c = absence.Id;
        // absenceDay2.flair__Workload_Amount_in_Minutes__c = 0;
        // insert absenceDay2;
    }

    @isTest
    static void test_batch() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getEmployeeAbsences_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            Database.executeBatch(new EmployeeAbsences_ScheduleBatch());
            Test.stopTest();
            Assert.areEqual(1, [SELECT Id FROM flair__Absence_Day__c WHERE Migration_ID__c != null].size(), 'Absence days not updated');
        }
        
    }

    @isTest
    static void test_schedule() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getEmployeeAbsences_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            EmployeeAbsences_ScheduleBatch.start(1);
            Test.stopTest();
            CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE CronExpression = '0 0 1 ? * *'];
            Datetime today = Datetime.now().addHours(1);
            System.assertEquals(Datetime.now().addHours(1).hour(), ct.NextFireTime.hour(), 'Job not scheduled in next hour');
        } 
    }
}