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
private class MSBCAPI_Test {

   @TestSetup
   static void setup() {
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
   } 

    @isTest
    static void test_setupAPI() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getAvailableCompanies_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            MSBCAPI.setupAPI();
            Assert.areEqual(true, [SELECT Name, Is_MSBC_Synched__c, flair__Migration_ID__c FROM flair__Entity__c WHERE Is_MSBC_Synched__c = true].size() > 0, 'Entity not synched');
            Test.stopTest();
        }
    }

    @isTest
    static void test_getHeaders(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getHeaders_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            MSBCAPI.PostedZDEHeaders result = MSBCAPI.getHeaders(entity.flair__Migration_ID__c);
            Assert.areEqual(String.isBlank(result.odataContext), false, 'odataContext is blank');
            Test.stopTest();
        }
    }

    @isTest
    static void test_getCausesOfAbsence() {
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getCausesOfAbsence_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            MSBCAPI.CausesOfAbsences results = MSBCAPI.getCausesOfAbsence(entity.flair__Migration_ID__c);
            Assert.areEqual(String.isBlank(results.odataContext), false, 'odataContext is blank');
            Test.stopTest();
        }
    }

    @isTest
    static void test_getEmployeesFlair(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getEmployeesFlair_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            MSBCAPI.EmployeesFlair results = MSBCAPI.getEmployeesFlair(entity.flair__Migration_ID__c);
            Assert.areEqual(String.isBlank(results.odataContext), false, 'odataContext is blank');
            Test.stopTest();
        }
    }

    @isTest
    static void test_getEmployeesStandard(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getEmployeesStandard_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            MSBCAPI.EmployeesStandard results = MSBCAPI.getEmployeesStandard(entity.flair__Migration_ID__c);
            Assert.areEqual(String.isBlank(results.odataContext), false, 'odataContext is blank');
            Test.stopTest();
        }
    }

    @isTest
    static void test_getAvailableCompanies(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getAvailableCompanies_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            MSBCAPI.Companies results = MSBCAPI.getAvailableCompanies();
            Assert.areEqual(String.isBlank(results.odataContext), false, 'odataContext is blank');
            Test.stopTest();
        }
    }

    @isTest
    static void test_createEmployeeAbscence(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getEmployeeAbsences_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            MSBCAPI.CreateEmployeeAbsencesRequest requestBody = new MSBCAPI.CreateEmployeeAbsencesRequest();
            requestBody.employeeNo = 'TESTMITARBEITER';
            requestBody.resourceNo = 'APU' ;
            requestBody.fromDate = '2025-01-06' ;
            requestBody.causeOfAbsenceCode = 'VACATION' ;
            requestBody.quantityBase = 5.0 ;
            MSBCAPI.CreateEmployeeAbsencesResponse results = MSBCAPI.createEmployeeAbscence(entity.flair__Migration_ID__c, requestBody);
            Assert.areEqual(String.isBlank(results.odataContext), false, 'odataContext is blank');
            Test.stopTest();
        }
    }

    @isTest
    static void test_getEmployeeAbsences(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getEmployeeAbsences_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            MSBCAPI.EmployeeAbsences results = MSBCAPI.getEmployeeAbsences(entity.flair__Migration_ID__c);
            Assert.areEqual(String.isBlank(results.odataContext), false, 'odataContext is blank');
            Test.stopTest();
        }
    }

    @isTest
    static void test_deleteEmployeeAbsences(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getEmployeeAbsences_Success');
            mock.setStatusCode(200);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            MSBCAPI.deleteEmployeeAbsences(entity.flair__Migration_ID__c, '00000000-0000-0000-0000-000000000000' );
            Test.stopTest();
        }
    }

    @isTest
    static void test_400(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getEmployeeAbsences_Success');
            mock.setStatusCode(400);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            try {
                MSBCAPI.deleteEmployeeAbsences(entity.flair__Migration_ID__c, '00000000-0000-0000-0000-000000000000' );
            } catch(Exception e) {
                Assert.areEqual('An MSBCAPI Callout failed', e.getMessage());
            }
            Test.stopTest();
        }
    }

    @isTest
    static void test_300(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
            mock.setStaticResource('MSBCAPI_getEmployeeAbsences_Success');
            mock.setStatusCode(300);
            mock.setHeader('Content-Type', 'application/json');
            Test.setMock(HttpCalloutMock.class, mock);
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            try {
                MSBCAPI.deleteEmployeeAbsences(entity.flair__Migration_ID__c, '00000000-0000-0000-0000-000000000000' );
            } catch(Exception e) {
                Assert.areEqual('An MSBCAPI Callout failed', e.getMessage());
            }
            Test.stopTest();
        }
    }

    @isTest
    static void test_Exception(){
        User contextuser = [SELECT Id FROM User WHERE Email = 'dummyuser@example.com'];
        System.runAs(contextuser){
            Test.startTest();
            flair__Entity__c entity = [SELECT Id, flair__Migration_ID__c FROM flair__Entity__c WHERE Name = 'Con4Mare GmbH & Cie. KG'];
            try {
                MSBCAPI.deleteEmployeeAbsences(entity.flair__Migration_ID__c, '00000000-0000-0000-0000-000000000000' );
            } catch(Exception e) {
                Assert.areEqual('An MSBCAPI Callout failed', e.getMessage());
            }
            Test.stopTest();
        }
    }
}