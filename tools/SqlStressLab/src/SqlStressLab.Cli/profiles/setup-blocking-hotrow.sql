{
  "profileName": "demo-blocking-sqloutput-separate",
  "scenarioName": "BlockingHotRow",
  "connection": {
    "server": "syriusz",
    "database": "StressLabDb",
    "authentication": "SqlPassword",
    "userName": "sa",
    "password": "",
    "encrypt": true,
    "trustServerCertificate": true,
    "applicationName": "SqlStressLab"
  },
  "execution": {
    "commandText": "dbo.usp_BlockingDemo",
    "commandType": "StoredProcedure",
    "executionMode": "NonQuery",
    "workers": 8,
    "iterationsPerWorker": 30,
    "commandTimeoutSeconds": 15,
    "useTransaction": false,
    "warmupEnabled": false,
    "warmupIterationsPerWorker": 0,
    "sessionSettingsFile": "session.sql",
    "delayBetweenIterationsMs": 0
  },
  "parameters": [
    {
      "name": "@Id",
      "type": "INT",
      "mode": "Fixed",
      "value": "1"
    }
  ],
  "retry": {
    "enabled": true,
    "maxRetries": 2,
    "delayMs": 300,
    "retryableSqlErrorNumbers": [1205, -2]
  },
  "sqlOutput": {
    "enabled": true,
    "connectionMode": "Separate",
    "connection": {
      "server": "syriusz",
      "database": "StressLabDb",
      "authentication": "SqlPassword",
      "userName": "sa",
      "password": "",
      "encrypt": true,
      "trustServerCertificate": true,
      "applicationName": "SqlStressLab.Repository"
    }
  },
  "lifecycle": {
    "setupEnabled": false,
    "cleanupEnabled": false,
    "setupScriptFile": "",
    "cleanupScriptFile": "",
    "stopRunWhenSetupFails": true,
    "continueWhenCleanupFails": true
  },
  "environment": {
    "environmentName": "Lab"
  },
  "compare": {
    "enabled": true,
    "mode": "PreviousRun",
    "baselineRunId": "",
    "includeSampleLevelDiff": false
  },
  "trend": {
    "enabled": true,
    "top": 10
  },
  "markdownReport": {
    "enabled": true,
    "directory": "outputs",
    "includeTopSlowestSamples": true,
    "topSlowestSamplesCount": 20,
    "includeErrorSummary": true
  },
  "htmlReport": {
    "enabled": true,
    "directory": "outputs",
    "includeDmvSection": true,
    "includeSlowSamples": true,
    "topSlowSamplesCount": 20
  },
  "tags": {
    "tags": ["demo", "blocking", "sqloutput", "separate", "sprint6"]
  },
  "output": {
    "writeJson": true,
    "writeCsv": true,
    "writeReaderPreview": false,
    "directory": "outputs"
  }
}