// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

// To setup MSBC API
MSBCAPI.setupAPI();
// To schedule Empoyee absence creation in MSBC
EmployeeAbsences_ScheduleBatch.start(1);
// To schedule Time Entries creation On 1 AM
TimeEntries_ScheduleBatch.start();
// Test create TimeEntries in Flair
Database.executebatch(new TimeEntries_ScheduleBatch());
// Test EmployeeAbsences in MSBC
Database.executebatch(new EmployeeAbsences_ScheduleBatch());