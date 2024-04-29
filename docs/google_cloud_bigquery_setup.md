# Google Cloud BigQuery Setup

Before you can start to use BigQuery and send events to it with `dfe-analytics`
you'll need to setup your project in the Google Cloud Platform (GCP).

## Initial Configuration

These steps need to be performed only once when you setup your Google Cloud
project.

### 1. Create a Google Cloud project

Ask in Slack on the `#twd_data_insights` channel for someone to help you create
your project in the `digital.education.gov.uk` Google Cloud Organisation.

Each team is responsible for managing their project in Google Cloud. Ensure
you've added users with the `Owner` role through the IAM section of Google
Cloud.

### 2. Set up billing

You also need to set up your GCP organisation instance with paid billing. This
is because `dfe-analytics` uses streaming, and streaming to BigQuery isn't
allowed in the free tier:

```
accessDenied: Access Denied: BigQuery BigQuery: Streaming insert is not allowed
in the free tier
```

The following steps can be accomplished without having billing setup, however
there are certain restrictions.

- Streaming data to BigQuery isn't allowed, so you won't be able to use
  `dfe_analytics`.
- Tables are limited to 60 days retention.

### 3. Create custom roles

We use customised roles to give permissions to users who need to use the
BigQuery.

Instructions are provided below and must be followed to create each role. There
are two approaches available to create custom roles, one is using the Google
Cloud shell CLI, which is appropriate for advanced users comfortable with
command-line interfaces. The other is through the Google Cloud IAM web UI and
requires more manual work especially when it comes to adding permissions.

<details> <summary>Instructions for GCloud CLI</summary>

> **NB:** These instructions are appropriate for people who are comfortable
> running shell commands.

1. Go to the IAM section of the Google Console for your project.
2. Click the ![Google Cloud shell button](google-cloud-shell-button.png) to
   activate the Google Cloud shell.
3. Copy the command provided into the shell, replacing `YOUR_PROJECT_ID` with
   your own project ID.

</details>

<details> <summary>Instructions for GCloud IAM Web UI</summary>

> **NB:** Adding permissions to a role is a manual process that requires using
> the permission browser to add permissions one at a time.

1. Go to the IAM section of the Google Console for your project.
1. Go to Roles section using the sidebar on the left.
1. Click on "+ Create role" near the top.
1. Fill in the details from the info below.

</details>

#### Basic Role

This role is used for analysts or other users who don't need to write to or
modify data in BigQuery.

<details> <summary>Using the GCloud CLI</summary>

``` bash
gcloud iam roles create bigquery_basic_custom --title="BigQuery Basic Custom" --description="Assigned to accounts used by analysts." --permissions=bigquery.connections.get,bigquery.dataPolicies.maskedGet,bigquery.datasets.get,bigquery.datasets.getIamPolicy,bigquery.datasets.updateTag,bigquery.jobs.create,bigquery.jobs.get,bigquery.jobs.list,bigquery.jobs.listAll,bigquery.models.export,bigquery.models.getData,bigquery.models.getMetadata,bigquery.models.list,bigquery.readsessions.create,bigquery.readsessions.getData,bigquery.readsessions.update,bigquery.routines.get,bigquery.routines.list,bigquery.savedqueries.create,bigquery.savedqueries.delete,bigquery.savedqueries.get,bigquery.savedqueries.list,bigquery.savedqueries.update,bigquery.tables.createSnapshot,bigquery.tables.export,bigquery.tables.get,bigquery.tables.getData,bigquery.tables.getIamPolicy,bigquery.tables.list,bigquery.tables.restoreSnapshot,datacatalog.entries.get,datacatalog.entries.list,datacatalog.entryGroups.get,datacatalog.entryGroups.list,datacatalog.tagTemplates.get,datacatalog.tagTemplates.getTag,datacatalog.taxonomies.get,datacatalog.taxonomies.list,datalineage.events.get,datalineage.events.list,datalineage.locations.searchLinks,datalineage.processes.get,datalineage.processes.list,datalineage.runs.get,datalineage.runs.list,iam.serviceAccounts.actAs,iam.serviceAccounts.get,iam.serviceAccounts.list,pubsub.topics.get,resourcemanager.projects.get --project=YOUR_PROJECT_ID
```

</details>

<details> <summary>Using the GCloud IAM Web UI</summary>

| Field             | Value                                                     |
|-------------------|-----------------------------------------------------------|
| Title             | **BigQuery Basic Custom**                               |
| Description       | Assigned to accounts used by analysts or other users who don't need to write to or modify data in BigQuery. |
| ID                | `bigquery_basic_custom`                                 |
| Role launch stage | General Availability                                      |
| + Add permissions | See below                                                 |

##### Permissions for `bigquery_basic_custom`

```
bigquery.connections.get
bigquery.dataPolicies.maskedGet
bigquery.datasets.get
bigquery.datasets.getIamPolicy
bigquery.datasets.updateTag
bigquery.jobs.create
bigquery.jobs.get
bigquery.jobs.list
bigquery.jobs.listAll
bigquery.models.export
bigquery.models.getData
bigquery.models.getMetadata
bigquery.models.list
bigquery.readsessions.create
bigquery.readsessions.getData
bigquery.readsessions.update
bigquery.routines.get
bigquery.routines.list
bigquery.savedqueries.create
bigquery.savedqueries.delete
bigquery.savedqueries.get
bigquery.savedqueries.list
bigquery.savedqueries.update
bigquery.tables.createSnapshot
bigquery.tables.export
bigquery.tables.get
bigquery.tables.getData
bigquery.tables.getIamPolicy
bigquery.tables.list
bigquery.tables.restoreSnapshot
datacatalog.entries.get
datacatalog.entries.list
datacatalog.entryGroups.get
datacatalog.entryGroups.list
datacatalog.tagTemplates.get
datacatalog.tagTemplates.getTag
datacatalog.taxonomies.get
datacatalog.taxonomies.list
datalineage.events.get
datalineage.events.list
datalineage.locations.searchLinks
datalineage.processes.get
datalineage.processes.list
datalineage.runs.get
datalineage.runs.list
iam.serviceAccounts.actAs
iam.serviceAccounts.get
iam.serviceAccounts.list
pubsub.topics.get
resourcemanager.projects.get
```

</details>

#### Advanced Role

This role is used for Dataform SQL developers or other users who need to be able to write to
or modify data in BigQuery.

<details> <summary>Using the GCloud CLI</summary>

``` bash
gcloud iam roles create bigquery_advanced_custom --title="BigQuery Advanced Custom" --description="Assigned to accounts used by Dataform SQL developers who need to be able to write to or modify data in BigQuery." --permissions=aiplatform.notebookRuntimeTemplates.apply,aiplatform.notebookRuntimeTemplates.get,aiplatform.notebookRuntimeTemplates.getIamPolicy,aiplatform.notebookRuntimeTemplates.list,aiplatform.notebookRuntimes.assign,aiplatform.notebookRuntimes.get,aiplatform.notebookRuntimes.list,aiplatform.operations.list,bigquery.config.get,bigquery.connections.create,bigquery.connections.delete,bigquery.connections.get,bigquery.connections.getIamPolicy,bigquery.connections.list,bigquery.connections.update,bigquery.connections.updateTag,bigquery.connections.use,bigquery.datasets.create,bigquery.datasets.delete,bigquery.datasets.get,bigquery.datasets.getIamPolicy,bigquery.datasets.update,bigquery.datasets.updateTag,bigquery.jobs.create,bigquery.jobs.delete,bigquery.jobs.get,bigquery.jobs.list,bigquery.jobs.listAll,bigquery.jobs.update,bigquery.models.create,bigquery.models.delete,bigquery.models.export,bigquery.models.getData,bigquery.models.getMetadata,bigquery.models.list,bigquery.models.updateData,bigquery.models.updateMetadata,bigquery.models.updateTag,bigquery.readsessions.create,bigquery.readsessions.getData,bigquery.readsessions.update,bigquery.routines.create,bigquery.routines.delete,bigquery.routines.get,bigquery.routines.list,bigquery.routines.update,bigquery.routines.updateTag,bigquery.savedqueries.create,bigquery.savedqueries.delete,bigquery.savedqueries.get,bigquery.savedqueries.list,bigquery.savedqueries.update,bigquery.tables.create,bigquery.tables.createSnapshot,bigquery.tables.delete,bigquery.tables.deleteSnapshot,bigquery.tables.export,bigquery.tables.get,bigquery.tables.getData,bigquery.tables.getIamPolicy,bigquery.tables.list,bigquery.tables.restoreSnapshot,bigquery.tables.setCategory,bigquery.tables.update,bigquery.tables.updateData,bigquery.tables.updateTag,datacatalog.categories.fineGrainedGet,datacatalog.entries.get,datacatalog.entries.list,datacatalog.entryGroups.get,datacatalog.entryGroups.list,datacatalog.tagTemplates.get,datacatalog.tagTemplates.getTag,datacatalog.taxonomies.get,datacatalog.taxonomies.list,dataform.compilationResults.create,dataform.compilationResults.get,dataform.compilationResults.list,dataform.compilationResults.query,dataform.locations.get,dataform.locations.list,dataform.releaseConfigs.create,dataform.releaseConfigs.delete,dataform.releaseConfigs.get,dataform.releaseConfigs.list,dataform.releaseConfigs.update,dataform.repositories.commit,dataform.repositories.computeAccessTokenStatus,dataform.repositories.create,dataform.repositories.delete,dataform.repositories.fetchHistory,dataform.repositories.fetchRemoteBranches,dataform.repositories.get,dataform.repositories.getIamPolicy,dataform.repositories.list,dataform.repositories.queryDirectoryContents,dataform.repositories.readFile,dataform.repositories.setIamPolicy,dataform.repositories.update,dataform.workflowConfigs.create,dataform.workflowConfigs.delete,dataform.workflowConfigs.get,dataform.workflowConfigs.list,dataform.workflowConfigs.update,dataform.workflowInvocations.cancel,dataform.workflowInvocations.create,dataform.workflowInvocations.delete,dataform.workflowInvocations.get,dataform.workflowInvocations.list,dataform.workflowInvocations.query,dataform.workspaces.commit,dataform.workspaces.create,dataform.workspaces.delete,dataform.workspaces.fetchFileDiff,dataform.workspaces.fetchFileGitStatuses,dataform.workspaces.fetchGitAheadBehind,dataform.workspaces.get,dataform.workspaces.getIamPolicy,dataform.workspaces.installNpmPackages,dataform.workspaces.list,dataform.workspaces.makeDirectory,dataform.workspaces.moveDirectory,dataform.workspaces.moveFile,dataform.workspaces.pull,dataform.workspaces.push,dataform.workspaces.queryDirectoryContents,dataform.workspaces.readFile,dataform.workspaces.removeDirectory,dataform.workspaces.removeFile,dataform.workspaces.reset,dataform.workspaces.searchFiles,dataform.workspaces.setIamPolicy,dataform.workspaces.writeFile,datalineage.events.get,datalineage.events.list,datalineage.locations.searchLinks,datalineage.processes.get,datalineage.processes.list,datalineage.runs.get,datalineage.runs.list,iam.serviceAccounts.actAs,iam.serviceAccounts.get,iam.serviceAccounts.list,logging.buckets.get,logging.buckets.list,logging.exclusions.get,logging.exclusions.list,logging.links.get,logging.links.list,logging.locations.get,logging.locations.list,logging.logEntries.list,logging.logMetrics.get,logging.logMetrics.list,logging.logServiceIndexes.list,logging.logServices.list,logging.logs.list,logging.operations.get,logging.operations.list,logging.queries.create,logging.queries.delete,logging.queries.get,logging.queries.list,logging.queries.listShared,logging.queries.update,logging.sinks.get,logging.sinks.list,logging.usage.get,logging.views.get,logging.views.list,pubsub.topics.get,resourcemanager.projects.get --project=YOUR_PROJECT_ID
```

</details>

<details> <summary>Using the GCloud IAM Web UI</summary>

| Field | Value |
| ----------------- | ---------------------------------------- |
| Title | **BigQuery Advanced Custom** |
| Description | Assigned to accounts used by Dataform SQL developers who need to be able to write to or modify data in BigQuery. |
| ID | `bigquery_advanced_custom` |
| Role launch stage | General Availability |
| + Add permissions | See below |

##### Permissions for `bigquery_advanced_custom`

```
aiplatform.notebookRuntimeTemplates.apply
aiplatform.notebookRuntimeTemplates.get
aiplatform.notebookRuntimeTemplates.getIamPolicy
aiplatform.notebookRuntimeTemplates.list
aiplatform.notebookRuntimes.assign
aiplatform.notebookRuntimes.get
aiplatform.notebookRuntimes.list
aiplatform.operations.list
bigquery.config.get
bigquery.connections.create
bigquery.connections.delete
bigquery.connections.get
bigquery.connections.getIamPolicy
bigquery.connections.list
bigquery.connections.update
bigquery.connections.updateTag
bigquery.connections.use
bigquery.datasets.create
bigquery.datasets.delete
bigquery.datasets.get
bigquery.datasets.getIamPolicy
bigquery.datasets.update
bigquery.datasets.updateTag
bigquery.jobs.create
bigquery.jobs.delete
bigquery.jobs.get
bigquery.jobs.list
bigquery.jobs.listAll
bigquery.jobs.update
bigquery.models.create
bigquery.models.delete
bigquery.models.export
bigquery.models.getData
bigquery.models.getMetadata
bigquery.models.list
bigquery.models.updateData
bigquery.models.updateMetadata
bigquery.models.updateTag
bigquery.readsessions.create
bigquery.readsessions.getData
bigquery.readsessions.update
bigquery.routines.create
bigquery.routines.delete
bigquery.routines.get
bigquery.routines.list
bigquery.routines.update
bigquery.routines.updateTag
bigquery.savedqueries.create
bigquery.savedqueries.delete
bigquery.savedqueries.get
bigquery.savedqueries.list
bigquery.savedqueries.update
bigquery.tables.create
bigquery.tables.createSnapshot
bigquery.tables.delete
bigquery.tables.deleteSnapshot
bigquery.tables.export
bigquery.tables.get
bigquery.tables.getData
bigquery.tables.getIamPolicy
bigquery.tables.list
bigquery.tables.restoreSnapshot
bigquery.tables.setCategory
bigquery.tables.update
bigquery.tables.updateData
bigquery.tables.updateTag
datacatalog.categories.fineGrainedGet
datacatalog.entries.get
datacatalog.entries.list
datacatalog.entryGroups.get
datacatalog.entryGroups.list
datacatalog.tagTemplates.get
datacatalog.tagTemplates.getTag
datacatalog.taxonomies.get
datacatalog.taxonomies.list
dataform.compilationResults.create
dataform.compilationResults.get
dataform.compilationResults.list
dataform.compilationResults.query
dataform.locations.get
dataform.locations.list
dataform.releaseConfigs.create
dataform.releaseConfigs.delete
dataform.releaseConfigs.get
dataform.releaseConfigs.list
dataform.releaseConfigs.update
dataform.repositories.commit
dataform.repositories.computeAccessTokenStatus
dataform.repositories.create
dataform.repositories.delete
dataform.repositories.fetchHistory
dataform.repositories.fetchRemoteBranches
dataform.repositories.get
dataform.repositories.getIamPolicy
dataform.repositories.list
dataform.repositories.queryDirectoryContents
dataform.repositories.readFile
dataform.repositories.setIamPolicy
dataform.repositories.update
dataform.workflowConfigs.create
dataform.workflowConfigs.delete
dataform.workflowConfigs.get
dataform.workflowConfigs.list
dataform.workflowConfigs.update
dataform.workflowInvocations.cancel
dataform.workflowInvocations.create
dataform.workflowInvocations.delete
dataform.workflowInvocations.get
dataform.workflowInvocations.list
dataform.workflowInvocations.query
dataform.workspaces.commit
dataform.workspaces.create
dataform.workspaces.delete
dataform.workspaces.fetchFileDiff
dataform.workspaces.fetchFileGitStatuses
dataform.workspaces.fetchGitAheadBehind
dataform.workspaces.get
dataform.workspaces.getIamPolicy
dataform.workspaces.installNpmPackages
dataform.workspaces.list
dataform.workspaces.makeDirectory
dataform.workspaces.moveDirectory
dataform.workspaces.moveFile
dataform.workspaces.pull
dataform.workspaces.push
dataform.workspaces.queryDirectoryContents
dataform.workspaces.readFile
dataform.workspaces.removeDirectory
dataform.workspaces.removeFile
dataform.workspaces.reset
dataform.workspaces.searchFiles
dataform.workspaces.setIamPolicy
dataform.workspaces.writeFile
datalineage.events.get
datalineage.events.list
datalineage.locations.searchLinks
datalineage.processes.get
datalineage.processes.list
datalineage.runs.get
datalineage.runs.list
iam.serviceAccounts.actAs
iam.serviceAccounts.get
iam.serviceAccounts.list
logging.buckets.get
logging.buckets.list
logging.exclusions.get
logging.exclusions.list
logging.links.get
logging.links.list
logging.locations.get
logging.locations.list
logging.logEntries.list
logging.logMetrics.get
logging.logMetrics.list
logging.logServiceIndexes.list
logging.logServices.list
logging.logs.list
logging.operations.get
logging.operations.list
logging.queries.create
logging.queries.delete
logging.queries.get
logging.queries.list
logging.queries.listShared
logging.queries.update
logging.sinks.get
logging.sinks.list
logging.usage.get
logging.views.get
logging.views.list
pubsub.topics.get
resourcemanager.projects.get
```

</details>

#### Appender Role

This role is assigned to the service account used by the application connecting
to Google Cloud to append data to the `events` tables.

<details> <summary>Using the GCloud CLI</summary>

``` bash
gcloud iam roles create bigquery_appender_custom --title="BigQuery Appender Custom" --description="Assigned to service accounts used to append data to events tables." --permissions=bigquery.datasets.get,bigquery.tables.get,bigquery.tables.updateData
```

</details>

<details> <summary>Using the GCloud IAM Web UI</summary>

| Field             | Value                                                              |
|-------------------|--------------------------------------------------------------------|
| Title             | **BigQuery Appender Custom**                                       |
| Description       | Assigned to service accounts used to append data to events tables. |
| ID                | `bigquery_appender_custom`                                         |
| Role launch stage | General Availability                                               |
| + Add permissions | See below                                                          |

##### Permissions for bigquery_appender_custom

```
bigquery.datasets.get
bigquery.tables.get
bigquery.tables.updateData
```

</details>

### 4. Create a policy tag
We use a BigQuery 'policy tag' to label some fields in some tables in BigQuery
as 'hidden', restrict access to these fields and mask data in these fields to
users without access. Policy tag(s) exist within a group known as a 'taxonomy'.

To create the 'hidden' policy tag required by dfe-analytics:
1. Enable the "BigQuery Data Policy API": search for this from the 'Enable APIs
   and services' screen, accessible from the 'Enabled APIs and services' screen
   within the 'APIs and services' section of GCP, and click 'Enable'.
2. Open BigQuery, open the 'Policy tags' screen and click 'Create taxonomy'.
3. Use this screen to create a policy tag named ‘hidden’ within a taxonomy named
   something like ‘project-restricted-access' (replacing ‘project’ with something
   meaningful to your GCP project). Ensure the taxonomy is within the
   europe-west2 (London) region.
4. Click the 'Manage data policies' button to open the Masking rules screen. Under
   'Data policy name 1' type 'hidden' and under 'Masking rule 1' select
   'Hash (SHA256)'. Click Submit.

## Dataset and Table Setup

`dfe-analytics` inserts events into a table in BigQuery with a pre-defined
schema. Access is given using a service account that has access to append data
to the given events table. The recommended setup is to have a separate dataset
and service account for each application / environment combination in your
project.

For example let's say you have the applications `publish` and `find` in your
project, and use `development`, `qa`, `staging` and `production` environments.
You should create a separate dataset for each combination of the above, as well
as a separate service account that has access to append data to events in only
one dataset. The following table illustrates how this might look for this
example:

| Application | Environment | BigQuery Dataset           | Service Account                                              |
|-------------|-------------|----------------------------|--------------------------------------------------------------|
| publish     | development | publish_events_development | appender-publish-development@project.iam.gserviceaccount.com |
| publish     | qa          | publish_events_qa          | appender-publish-qa@project.iam.gserviceaccount.com          |
| publish     | staging     | publish_events_staging     | appender-publish-staging@project.iam.gserviceaccount.com     |
| publish     | production  | publish_events_production  | appender-publish-production@project.iam.gserviceaccount.com  |
| find        | development | find_events_development    | appender-find-development@project.iam.gserviceaccount.com    |
| find        | qa          | find_events_qa             | appender-find-qa@project.iam.gserviceaccount.com             |
| find        | staging     | find_events_staging        | appender-find-staging@project.iam.gserviceaccount.com        |
| find        | production  | find_events_production     | appender-find-production@project.iam.gserviceaccount.com     |

This approach helps prevent the possibility of sending events to the wrong
dataset, and reduce the risk should a secret key for one of these accounts
be leaked.

> **NB:** It may be easier to perform these instructions with two browser tabs
> open, one for BigQuery and the other for IAM

### 1. Create dataset(s)

Start by creating a dataset.

1. Open your project's BigQuery instance and go to the SQL Workspace section.
2. Tap on the 3 dots next to the project name then "Create dataset".
3. Name it something like `APPLICATIONNAME_events_ENVIRONMENT`, as per above
   examples, e.g. `publish_events_development`, and set the location to
   `europe-west2 (London)`.

### 2. Create the events table

Once the dataset is ready you need to create the `events` table in it:

1. Select your new dataset and click the ![BigQuery new query
   button](bigquery-new-query-button.png) to open a new query execution tab.
2. Copy the contents of [create-events-table.sql](create-events-table.sql)
   into the query editor.
3. Edit your project and dataset names in the query editor.
4. Run the query to create a blank events table.
5. Label the DATA_hidden field with the 'hidden' policy tag to restrict
   access to it: Navigate to the newly created table in BigQuery using the
   left hand sidebar. Click 'Edit Schema'. Expand the 'DATA_hidden' field
   and select the checkbox next to the 'value' element within it. Click
   'Add policy tag' and select the 'hidden' policy tag in the taxonomy for
   your project. Click Save.

BigQuery allows you to copy a table to a new dataset, so now is a good time to
create all the datasets you need and copy the blank `events` table to each of
them.

### 3. Create an appender service account

Create a service account that will be given permission to append data to tables
in the new dataset.

1. Go to [IAM and Admin settings > Create service
   account](https://console.cloud.google.com/projectselector/iam-admin/serviceaccounts/create?supportedpurview=project)
2. Name it like "Appender NAME_OF_SERVICE ENVIRONMENT" e.g. "Appender
   ApplyForQTS Development".
3. Add a description, like "Used for appending data from development
   environments."
4. Copy the email address using the button next to it. You'll need this in the
   next step to give this account access to your dataset.
5. Click the "CREATE AND CONTINUE" button.
6. Click "DONE", skipping the steps to grant roles and user access to this
   account. Access will be given to the specific dataset in the next step.

### 4. Give the service account access to your dataset 

Ensure you have the email address of the service account handy for this.

1. Go to the dataset you created and click "SHARING" > "Permissions" near the
   top right.
2. Click "ADD PRINCIPAL".
3. Paste in the email address of the service account you created into the "New
   principals" box.
4. Select the "BigQuery Appender Custom" role you created previously.
5. Click "SAVE" to finish.
