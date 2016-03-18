# About Nuxeo Benchmarks

Helper scripts for the Nuxeo reference benchmarks.

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

Benchmarks are launched using Jenkins and populate a reference site:
http://qa.nuxeo.org/benchmarks/

## Benchmark workflow

### Running a benchmark

New benchmark are triggered using the following Jenkins job:
http://qa.nuxeo.org/jenkins/job/nuxeo-reference-bench/

The job has parameters that impact the target Nuxeo setup:

- dbprofile: the backend used for the repository
- nbnodes: the number of nodes in the Nuxeo cluster
- distribution: the Nuxeo distribution to test, can be a branch with a different Nuxeo tuning for instance.

There are parameters that help to categorize the benchmarks results:

- benchname
- classifier

The `benchname` is the same for all benchmark that attempt to test a common target with differeent axis.
Typical values for `benchname` can be: `Nuxeo 8.1` or `Current Snaphot`.

The variation for each run will be on `dbprofile`, `nbnodes` or `distribution`, you can use the classifier to add an extra note
about the target like: "db invalidation" or "postgresql tuned"

When displaying a list of benchmarks for a benchname, the list will be ordered by "$dbprofile $nbnodes $buildid",
and the name displayed will contain the classifier.


### Adding a benchmark result to the reference site

The Jenkins job is launched automatically after a bench to extract the results and push them to the site:
http://qa.nuxeo.org/jenkins/job/nuxeo-reference-site-add/


By default the results is categorized under the "Continuous results".

You can manually run the job to add a build to another categories : milestone or misc.


### Removing a benchmark result from the site

Using the same Jenkins job just check the "remove from the site" case :
http://qa.nuxeo.org/jenkins/job/nuxeo-reference-site-add/


### Updating the site

When modifying the site source from git:
https://github.com/nuxeo/nuxeo-bench-site


The update job is automatically launched:
http://qa.nuxeo.org/jenkins/job/nuxeo-reference-site/



## Release Benchmark protocol

 Use the trigger job: http://qa.nuxeo.org/jenkins/job/trigger-nuxeo-reference-bench/

 Choose a benchname like: Nuxeo 8.1

 Use the following job to add the results in the "milestone" category:
 http://qa.nuxeo.org/jenkins/job/nuxeo-reference-site-add/

 Soon the resutls will be listed on the site:
 http://qa.nuxeo.org/benchmarks/milestone/


# About Nuxeo

Nuxeo provides a modular, extensible, open source
[platform for enterprise content management](http://www.nuxeo.com/products/content-management-platform) used by organizations worldwide to power business processes and content repositories in the area of
[document management](http://www.nuxeo.com/solutions/document-management),
[digital asset management](http://www.nuxeo.com/solutions/digital-asset-management),
[case management](http://www.nuxeo.com/case-management) and [knowledge management](http://www.nuxeo.com/solutions/advanced-knowledge-base/). Designed
by developers for developers, the Nuxeo platform offers a modern
architecture, a powerful plug-in model and top notch performance.

More information on: <http://www.nuxeo.com/>
