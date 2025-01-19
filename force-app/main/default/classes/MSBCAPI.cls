public with sharing class MSBCAPI {

  public static final String API_ENDPOINT = 'callout:Named_Cred_01/v2.0/128f5fbc-6272-475d-a3c5-fd73bfd47dd3/';
  public static final String ENVIRONMENT = MSBC_API_Configuration__mdt.getInstance('Dev').Environment__c;
  private static final Integer MAX_RETRIES = 3;
  // private static final Integer DELAY_TIME_MINUTES = 5; // Delay time in minutes
  private static Integer retryCount;

  public static String callApi(
    String requestEndpoint,
    String requestMethod,
    String body
  ) {
    try {
      Http http = new Http();
      HttpRequest request = new HttpRequest();
      request.setEndpoint(requestEndpoint);
      request.setMethod(requestMethod);
      
      if (body != null) {
        request.setBody(body);
        request.setHeader('Content-Type', 'application/json');
      }
      HttpResponse response = http.send(request);
      if (String.valueOf(response.getStatusCode()).startsWith('20')) {
        Logger.info('Callout succeeded: ' + response.getStatusCode());
        return response.getBody();
      } else {
        Logger.error('An error occured while calling the API').setMessage(String.valueOf(response.getStatusCode())).setMessage(response.getStatus()).setMessage(response.getBody());
        retryCount++;
        if (retryCount < MAX_RETRIES) {
            // Schedule the retry after the delay time
            CalloutRetryHandler.scheduleRetry(requestEndpoint, requestMethod, body);
        } else {
          Logger.info('Max retries reached. Callout failed.');
        }
      }
    } catch (Exception ex) {
      Logger.error('An error while calling the API').setMessage(ex.getMessage());
      retryCount++;
      if (retryCount < MAX_RETRIES) {
          // Schedule the retry after the delay time
          CalloutRetryHandler.scheduleRetry(requestEndpoint, requestMethod, body);
      } else {
          Logger.info('Max retries reached. Callout failed.');
      }
    }
    return null;
  }

  public class ErrorResponse {
    public String code { get; set; }
    public String message { get; set; }
  }

  public static void setupAPI() {
    // Call the API to get the available companies
    Companies companies = getAvailableCompanies();
    Map<String, String> companyMap = new Map<String, String>();
    for( Company cp : companies.value ) {
      companyMap.put(cp.displayName, cp.id);
    }
    List<flair__Entity__c> entities =  [SELECT Name, Is_MSBC_Synched__c, flair__Migration_ID__c FROM flair__Entity__c];  
    for( flair__Entity__c entity : entities) {
      if( companyMap.containsKey(entity.Name) ) {
        entity.flair__Migration_ID__c = companyMap.get(entity.Name);
        entity.Is_MSBC_Synched__c = true;
      }
    }
    update entities;
  }

  public static PostedZDEHeaders getHeaders( String companyId ) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/postedZdeHeaders?$top=5&$filter=resNo+eq+\'APU\''; // and date gt 2024-01-01&$skip=100 // DateTime.newInstance( System.Today(), Time.newInstance(0,0,0,0)).format('yyyy-MM-dd') //top=100
    // String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/postedZdeHeaders?$filter=date+eq+'+ DateTime.newInstance(System.Today(), Time.newInstance(0,0,0,0)).addDays(-1).format('yyyy-MM-dd');
    requestEndpoint = requestEndpoint.replace(' ', '+');
    retryCount = 0;
    return parseGetHeaders(callApi(requestEndpoint, 'GET', null));
  }

  public static CausesOfAbsences getCausesOfAbsence(String companyId) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/causesOfAbsence';
    retryCount = 0;
    return parseGetCausesOfAbsence(callApi(requestEndpoint, 'GET', null));
  }

  public static EmployeesFlair getEmployeesFlair(String companyId) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/employees?$filter=status eq \'Active\'';
    requestEndpoint = requestEndpoint.replace(' ', '+');
    retryCount = 0;
    return parseGetEmployeesFlair(callApi(requestEndpoint, 'GET', null));
  }

  public static EmployeesStandard getEmployeesStandard(String companyId) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/employees';
    retryCount = 0;
    return parseGetEmployeesStandard(callApi(requestEndpoint, 'GET', null));
  }

  public static Companies getAvailableCompanies() {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies'; // $filter=resNo eq 'APU' and date gt 2024-01-01&$skip=100
    requestEndpoint = requestEndpoint.replace(' ', '+');
    retryCount = 0;
    return parseGetAvailableCompanies(callApi(requestEndpoint, 'GET', null));
  }

  public static CreateEmployeeResponse createEmployeeAbscence( String companyId, CreateEmployeeRequest requestBody ) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + CompanyId + ')/employeeAbsences';
    retryCount = 0;
    return parseCreateEmployeeAbscence(callApi(requestEndpoint, 'POST', JSON.serialize(requestBody)));
  }

  public static EmployeeAbsences getEmployeeAbsences(String companyId) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/employeeAbsences?$top=100';
    retryCount = 0;
    return parseGetEmployeeAbsences(callApi(requestEndpoint, 'GET', null));
  }

  private static PostedZDEHeaders parseGetHeaders( String response ) {
    response = response.replace('"date":', '"xdate":');
    response = response.replace('"@odata.context":', '"odataContext":');
    response = response.replace('"@odata.etag":', '"odataEtag":');
    return (PostedZDEHeaders) JSON.deserialize(
      response,
      PostedZDEHeaders.class
    );
  }

  private static CausesOfAbsences parseGetCausesOfAbsence( String response ) {
    response = response.replace('"@odata.context":', '"odataContext":');
    response = response.replace('"@odata.etag":', '"odataEtag":');
    return (CausesOfAbsences) JSON.deserialize(
      response,
      CausesOfAbsences.class);
  }

  private static EmployeesFlair parseGetEmployeesFlair( String response ) {
    response = response.replace('"@odata.context":', '"odataContext":');
    response = response.replace('"@odata.etag":', '"odataEtag":');
    return (EmployeesFlair) JSON.deserialize(
      response,
      EmployeesFlair.class);
  }

  private static EmployeesStandard parseGetEmployeesStandard( String response ) {
    response = response.replace('"@odata.context":', '"odataContext":');
    response = response.replace('"@odata.etag":', '"odataEtag":'); 
    response = response.replace('"xnumber":', '"number":'); 
    return (EmployeesStandard) JSON.deserialize(
      response,
      EmployeesStandard.class);
  }

  private static Companies parseGetAvailableCompanies( String response ) {
    response = response.replace('"@odata.context":', '"odataContext":');
    return (Companies) JSON.deserialize(
      response,
      Companies.class);
  }

  private static CreateEmployeeResponse parseCreateEmployeeAbscence( String response ) {
    response = response.replace('"@odata.context":', '"odataContext":');
    response = response.replace('"@odata.etag":', '"odataEtag":');
    return (CreateEmployeeResponse) JSON.deserialize(
      response,
      CreateEmployeeResponse.class);
  }

  private static EmployeeAbsences parseGetEmployeeAbsences( String response ) {
    response = response.replace('"@odata.context":', '"odataContext":');
    response = response.replace('"@odata.etag":', '"odataEtag":');
    return (EmployeeAbsences) JSON.deserialize(
      response,
      EmployeeAbsences.class);
  }

  public class PostedZDEHeaders {
    public String odataContext { get; set; }
    public List<Header> value { get; set; }
  }

  public class Header {
    public String odataEtag { get; set; }
    public String id { get; set; }
    public String xdate { get; set; }
    public String resNo { get; set; }
    public String fromTime { get; set; }
    public String toTime { get; set; }
    public Decimal breakTime { get; set; }
    public Decimal quantity { get; set; }
    public String employeeNo { get; set; }
  }

  public class CausesOfAbsences {
    public String odataContext { get; set; }
    public List<AbsenceCause> value { get; set; }
  }

  public class AbsenceCause {
    public String odataEtag { get; set; }
    public String id { get; set; }
    public String code { get; set; }
    public String description { get; set; }
  }  

  public class EmployeesFlair {
    public String odataContext { get; set; }
    public List<EmployeeFlair> value { get; set; }
  }

  public class EmployeeFlair {
    public String odataEtag { get; set; }
    public String systemId { get; set; }
    public String no { get; set; }
    public String firstName { get; set; }
    public String middleName { get; set; }
    public String lastName { get; set; }
    public String resourceNo { get; set; }
    public String status { get; set; }
  }

  public class EmployeesStandard {
    public String odataContext { get; set; }
    public List<EmployeeStandard> value { get; set; }
  }

  public class EmployeeStandard {
    public String odataEtag { get; set; }
    public String id { get; set; }
    public String xnumber { get; set; }
    public String displayName { get; set; }
    public String givenName { get; set; }
    public String middleName { get; set; }
    public String surname { get; set; }
    public String jobTitle { get; set; }
    public String addressLine1 { get; set; }
    public String addressLine2 { get; set; }
    public String city { get; set; }
    public String state { get; set; }
    public String country { get; set; }
    public String postalCode { get; set; }
    public String phoneNumber { get; set; }
    public String mobilePhone { get; set; }
    public String email { get; set; }
    public String personalEmail { get; set; }
    public String employmentDate { get; set; }
    public String terminationDate { get; set; }
    public String status { get; set; }
    public String birthDate { get; set; }
    public String statisticsGroupCode { get; set; }
    public String lastModifiedDateTime { get; set; }
  }

  public class Companies {
    public String odataContext { get; set; }
    public List<Company> value { get; set; }
  }

  public class Company {
    public String id { get; set; }
    public String systemVersion { get; set; }
    public Integer timestamp { get; set; }
    public String name { get; set; }
    public String displayName { get; set; }
    public String businessProfileId { get; set; }
    public String systemCreatedAt { get; set; }
    public String systemCreatedBy { get; set; }
    public String systemModifiedAt { get; set; }
    public String systemModifiedBy { get; set; }
  }

  public class CreateEmployeeRequest {
    public String employeeNo { get; set; }
    public String resourceNo { get; set; }
    public String fromDate { get; set; }
    public String causeOfAbsenceCode { get; set; }
    public Decimal quantityBase { get; set; }
  }

  public class CreateEmployeeResponse {
    public String odataContext { get; set; }
    public String odataEtag { get; set; }
    public String id { get; set; }
    public String employeeNo { get; set; }
    public String resourceNo { get; set; }
    public String fromDate { get; set; }
    public String causeOfAbsenceCode { get; set; }
    public Decimal quantityBase { get; set; }
  }

  public class EmployeeAbsences {
    public String odataContext { get; set; }
    public List<EmployeeAbsence> value { get; set; }
  }

  public class EmployeeAbsence {
    public String odataEtag { get; set; }
    public String id { get; set; }
    public String employeeNo { get; set; }
    public String resourceNo { get; set; }
    public String fromDate { get; set; }
    public String causeOfAbsenceCode { get; set; }
    public Decimal quantityBase { get; set; }
  }
}