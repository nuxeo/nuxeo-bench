To change the graphite dashboard either:

Edit the json version either:
- Modify the json file and paste the content in graphite Dashboard/Edit, then save the dashboard.
- Edit the dashboard from graphite and save, copy the json from Dashboard/Edit then paste into the file.

Extract the yml version using https://github.com/blacked/graphite-dashboardcli
graphite-dashboardcli copy nuxeo-bench http://bench-mgmt.nuxeo.org ./yml

Setup the dashboard: 
graphite-dashboardcli copy nuxeo-bench ./yml http://bench-mgmt.nuxeo.org
