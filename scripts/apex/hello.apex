// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

// To schedule batch jobs
MSBCAPI.setupAPI();
EmployeeAbsences_ScheduleBatch.start(1);
TimeEntries_ScheduleBatch.start();
// For test
Database.executebatch(new TimeEntries_ScheduleBatch());
Database.executebatch(new EmployeeAbsences_ScheduleBatch());