public with sharing class MSBCAPI {

  public static final String API_ENDPOINT = 'callout:Named_Cred_01/v2.0/128f5fbc-6272-475d-a3c5-fd73bfd47dd3/';
  public static final String ENVIRONMENT = MSBC_API_Configuration__mdt.getInstance('Production').Environment__c;
  private static final Integer MAX_ATTEMPTS = (Integer) MSBC_API_Configuration__mdt.getInstance('Production').Max_Attempts__c;
  private Integer currentAttempt = 1;

  public String callApi(
    String requestEndpoint,
    String requestMethod,
    String body
  ) {
    Http http = new Http();
    HttpRequest request = new HttpRequest();
    request.setEndpoint(requestEndpoint);
    request.setMethod(requestMethod);
    
    if (body != null) {
      request.setBody(body);
      request.setHeader('Content-Type', 'application/json');
    }
    while (currentAttempt < MAX_ATTEMPTS) {
      try {
        HttpResponse response = http.send(request);
        if (String.valueOf(response.getStatusCode()).startsWith('20')) {
          Logger.info('Callout succeeded: ' + response.getStatusCode());
          return response.getBody();
        } else {
          Logger.error('An error occured while calling the API').setMessage(String.valueOf(response.getStatusCode())).setMessage(response.getStatus()).setMessage(response.getBody());
          currentAttempt++;
          if( new List<Integer>{400, 401, 403, 404}.contains(response.getStatusCode())){
            Logger.error('No retry sever error. Callout failed.');
            CalloutRetryHandler.sendNotificationEmail(requestEndpoint, requestMethod, body, response.getBody());
            break;
          } else {
            Logger.error('Max retries reached. Callout failed.');
            CalloutRetryHandler.sendNotificationEmail(requestEndpoint, requestMethod, body, response.getBody());
            break;
          }
        }
      } catch (Exception ex) {
        currentAttempt++;
        Logger.error('An error while calling the API').setMessage(ex.getMessage());
        CalloutRetryHandler.sendNotificationEmail(requestEndpoint, requestMethod, body, ex.getMessage());
      }
    }
    Logger.saveLog();
    throw new CalloutException('An MSBCAPI Callout failed');
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
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/postedZdeHeaders?$filter='+
    'modifiedAt+ge+'+System.now().addDays(-7).format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')+'+and+date+ge+'+ DateTime.newInstance(System.today().addMonths(-2).toStartOfMonth(), Time.newInstance(0,0,0,0)).format('yyyy-MM-dd');
    requestEndpoint = requestEndpoint.replace(' ', '+');
    return parseGetHeaders(new MSBCAPI().callApi(requestEndpoint, 'GET', null));
  }

  public static CausesOfAbsences getCausesOfAbsence(String companyId) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/causesOfAbsence';

    return parseGetCausesOfAbsence(new MSBCAPI().callApi(requestEndpoint, 'GET', null));
  }

  public static EmployeesFlair getEmployeesFlair(String companyId) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/employees?$filter=status+eq+\'Active\'';
    requestEndpoint = requestEndpoint.replace(' ', '+');
    return parseGetEmployeesFlair(new MSBCAPI().callApi(requestEndpoint, 'GET', null));
  }

  public static EmployeesStandard getEmployeesStandard(String companyId) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/v2.0/companies(' + companyId + ')/employees?$filter=status+eq+\'Active\'';
    return parseGetEmployeesStandard(new MSBCAPI().callApi(requestEndpoint, 'GET', null));
  }

  public static Companies getAvailableCompanies() {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies';
    requestEndpoint = requestEndpoint.replace(' ', '+');
    return parseGetAvailableCompanies(new MSBCAPI().callApi(requestEndpoint, 'GET', null));
  }

  public static CreateEmployeeAbsencesResponse createEmployeeAbscence( String companyId, CreateEmployeeAbsencesRequest requestBody ) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + CompanyId + ')/employeeAbsences';
    return parseCreateEmployeeAbscence(new MSBCAPI().callApi(requestEndpoint, 'POST', JSON.serialize(requestBody)));
  }

  public static EmployeeAbsences getEmployeeAbsences(String companyId) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/employeeAbsences?$top=100';
    return parseGetEmployeeAbsences(new MSBCAPI().callApi(requestEndpoint, 'GET', null));
  }

  public static void deleteEmployeeAbsences(String companyId, String absenceId) {
    String requestEndpoint = API_ENDPOINT + ENVIRONMENT + '/api/kvs/flair/v1.0/companies(' + companyId + ')/employeeAbsences(' + absenceId + ')';
    new MSBCAPI().callApi(requestEndpoint, 'DELETE', null);
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

  private static CreateEmployeeAbsencesResponse parseCreateEmployeeAbscence( String response ) {
    response = response.replace('"@odata.context":', '"odataContext":');
    response = response.replace('"@odata.etag":', '"odataEtag":');
    return (CreateEmployeeAbsencesResponse) JSON.deserialize(
      response,
      CreateEmployeeAbsencesResponse.class);
  }

  private static EmployeeAbsences parseGetEmployeeAbsences( String response ) {
    response = response.replace('"@odata.context":', '"odataContext":');
    response = response.replace('"@odata.etag":', '"odataEtag":');
    return (EmployeeAbsences) JSON.deserialize(
      response,
      EmployeeAbsences.class);
  }

  public class PostedZDEHeaders {
    public String odataContext;
    public List<Header> value;
  }

  public class Header {
    public String odataEtag;
    public String id;
    public String xdate;
    public String resNo;
    public String fromTime;
    public String toTime;
    public Decimal breakTime;
    public Decimal quantity;
    public String employeeNo;
    public String shoringModelCode;
  }

  public class CausesOfAbsences {
    public String odataContext;
    public List<AbsenceCause> value;
  }

  public class AbsenceCause {
    public String odataEtag;
    public String id;
    public String code;
    public String description;
  }  

  public class EmployeesFlair {
    public String odataContext;
    public List<EmployeeFlair> value;
  }

  public class EmployeeFlair {
    public String odataEtag;
    public String systemId;
    public String no;
    public String firstName;
    public String middleName;
    public String lastName;
    public String resourceNo;
    public String status;
  }

  public class EmployeesStandard {
    public String odataContext;
    public List<EmployeeStandard> value;
  }

  public class EmployeeStandard {
    public String odataEtag;
    public String id;
    public String xnumber;
    public String displayName;
    public String givenName;
    public String middleName;
    public String surname;
    public String jobTitle;
    public String addressLine1;
    public String addressLine2;
    public String city;
    public String state;
    public String country;
    public String postalCode;
    public String phoneNumber;
    public String mobilePhone;
    public String email;
    public String personalEmail;
    public String employmentDate;
    public String terminationDate;
    public String status;
    public String birthDate;
    public String statisticsGroupCode;
    public String lastModifiedDateTime;
  }

  public class Companies {
    public String odataContext;
    public List<Company> value;
  }

  public class Company {
    public String id;
    public String systemVersion;
    public Integer timestamp;
    public String name;
    public String displayName;
    public String businessProfileId;
    public String systemCreatedAt;
    public String systemCreatedBy;
    public String systemModifiedAt;
    public String systemModifiedBy;
  }

  public class CreateEmployeeAbsencesRequest {
    public String employeeNo;
    public String resourceNo;
    public String fromDate;
    public String causeOfAbsenceCode;
    public Decimal quantityBase;
  }

  public class CreateEmployeeAbsencesResponse {
    public String odataContext;
    public String odataEtag;
    public String id;
    public String employeeNo;
    public String resourceNo;
    public String fromDate;
    public String causeOfAbsenceCode;
    public Decimal quantityBase;
  }

  public class EmployeeAbsences {
    public String odataContext;
    public List<EmployeeAbsence> value;
  }

  public class EmployeeAbsence {
    public String odataEtag;
    public String id;
    public String employeeNo;
    public String resourceNo;
    public String fromDate;
    public String causeOfAbsenceCode;
    public Decimal quantityBase;
  }

  public class CreateEmployeeRequestParams {
    public String companyId;
    public String absenceDayId;
    public MSBCAPI.CreateEmployeeAbsencesRequest data;
  }

  public class DeleteEmployeeAbsencesRequestParams {
    public String companyId;
    public String absenceDayId;
  }
}