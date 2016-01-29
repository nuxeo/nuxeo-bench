# About Nuxeo bench

Helper scripts for the Nuxeo reference benches.

This sets up an infrastructure with:

- an ELB
- Nuxeo nodes setup in cluster
- ES nodes
- a database node
- optionally, a mongodb node
- Redis in ElastiCache
- a S3 bucket for the binaries

This is a mix of static and dynamic parts:

- the Nuxeo and ES nodes are started/created on demand
- the database/mongodb nodes are started on demand (but not created)
- the ELB, ElastiCache and S3 bucket are static and always up

The bench is a composed of a dozen of gatling simulation.

## Benchmark workflow

### Running a benchmark

New benchmark are triggered using the following Jenkins job:
http://qa.nuxeo.org/jenkins/job/nuxeo-reference-bench/


There are parameters that impact the target installations:

- dbprofile: the backend used for the repository
- nbnodes: the number of nodes in the Nuxeo cluster
- distribution: the Nuxeo distribution to test, can be a branch with a different Nuxeo tuning for instance.

There are parameters that help to categorize the benchmarks:

- benchid
- benchname
- classifier

The `benchid/benchname` is the same for all benchmark that attempt to test a common target with differeent axis. 
Typical value for `benchid/benchname` can be: `nuxeo81/Nuxeo 8.1` or `master/Current Snaphot`. 
 
The variation for each run will be on `dbprofile`, `nbnodes` or `distribution`, you can use the classifier to add an extra note
about the target like: "db invalidation" or "postgresql tuned" 
  
When displaying a list of benchmarks for a benchname, the list will be ordered by "$dbprofile $nbnodes $buildid",
and the name displayed will contain the classifier.
 

### Adding a benchmark result to the reference site

The Jenkins job is launched automatically after a bench to extract the results and push them to the site:
http://qa.nuxeo.org/jenkins/job/nuxeo-reference-bench/


By default the results is categorized under the "Continuous resutls".

You can manually run the job to add a build to another categories : milestone or misc.


### Removing a benchmark result from the site

Using the same Jenkins job just check the "remove from the site" case :
http://qa.nuxeo.org/jenkins/job/nuxeo-reference-bench/


### Updating the site

When modifying the site source from git:
https://github.com/nuxeo/nuxeo-bench-site


The update job is automatically launched:
http://qa.nuxeo.org/jenkins/job/nuxeo-reference-site/



## Benchmark protocol for release
 
 First choose a benchid/benchname like: nuxeo81/Nuxeo 8.1 and keep it for all the runs.

 Then Schedule bench with http://qa.nuxeo.org/jenkins/job/nuxeo-reference-bench/
  
  - one per dbprofile 
  - dbprofile=mongodb with nbnodes 1, 3, 4
  - dbprofile=postgrsql with nbnodes 1, 3, 4
 
 There is no need to use a classifier here.
 

 

# About Nuxeo

Nuxeo provides a modular, extensible Java-based
[open source software platform for enterprise content management](http://www.nuxeo.com/en/products/ep)
and packaged applications for
[document management](http://www.nuxeo.com/en/products/document-management),
[digital asset management](http://www.nuxeo.com/en/products/dam) and
[case management](http://www.nuxeo.com/en/products/case-management). Designed
by developers for developers, the Nuxeo platform offers a modern
architecture, a powerful plug-in model and extensive packaging
capabilities for building content applications.

More information on: <http://www.nuxeo.com/>
