# About Nuxeo Benchmarks

Scripts used to run the Nuxeo reference benchmarks.

This sets up an infrastructure with:

- A Nuxeo cluster (AWS ec2)
- An Elasticsearch cluster (AWS ec2)
- A relational database or MongoDB (AWS ec2)
- Optionally, a Kafka cluster (AWS ec2)
- A binary store (AWS S3 bucket)
- Redis (AWS ElastiCache)
- A load balancer (AWS ELB)

This is a mix of static and dynamic parts:

- Nuxeo, Elasticsearch and Kafka ec2 nodes are created and terminated
- Database ec2 nodes are started on demand (but not created)
- ELB, ElastiCache and S3 bucket are static and always up

The bench is a composed of a dozen of Gatling simulation part of the Nuxeo source code.

Benchmarks are launched using Jenkins and populate a benchmark reference site:
https://benchmarks.nuxeo.com/

## Benchmark workflow

### Running a benchmark

Benchmarks are triggered using the following Jenkins job:
https://qa.nuxeo.org/jenkins/job/Misc/job/nuxeo-reference-bench/

The job has parameters that impact the target Nuxeo setup:

|parameter| default | description |
| --- | ---: | --- |
| `dbprofile` | `pgsql` | The backend used for the document repository |
| `distribution` | `laststapshot` | The Nuxeo distribution to use (must be >= 10.10):<br> - lastbuild: the last build from nuxeo-distribution-master<br> - lastitbuild: the last IT build distribution <br> - lastitsuccess the last successful IT build distribution <br> - lastlts: the latest LTS from cdn.nuxeo.com <br> - lastft: the latest FastTrack from cdn.nuxeo.com <br> - lastsnapshot: the latest published snapshot from community.nuxeo.com <br> - VERSION: that version from community.nuxeo.com SNAPSHOT) or cdn.nuxeo.com release) <br> - URL: downloads that URL, no resolving done <br> - FILE: uses that local file <br> - BRANCH: build a distrib from source using this branch - BRANCH/FALLBACK: build a distrib from source using this branch fallback on FALLBACK branch - BRANCH@DATE: build a distrib from source using a branch as it was at the DATE, for instance master@2017-04-24 |
| `nbnodes` | 2 | Number of Nuxeo nodes |
| `esnode` | 3 | Number of Elasticsearch nodes |
| `kafka` | false | Use kafka |
| `DEBUG_MODE` | false | This will wait 1h for manual intervention/debug before starting simulations.|
| `NUXEO_10` | false | The target is a Nuxeo 10.10, requiring Java 8 to build, using different path for simulation. |


There are parameters that help to categorize the benchmarks results:

|parameter| default | description |
| --- | ---: | --- |
| `benchsuite` | `Current snapshot` | The name used to mark a serie of benchmark on a Nuxeo build. This field is used to group benchmark results on the benchmark reference site. To get a good ordering of reports it is a good idea to prefix with a date formated like '17w03' for 2017 week number 3. You should also add a NXP reference, ex: '17w10 NXP-12345 Evaluate Foo refactoring |
| `classifier` | | An additional classifier for the benchmark when something other than dbprofile or nbnodes has changed. You can use 'reference' to get a baseline benchmark.|
| `category` | `workbench` | The results category where the result is added: <br>  - milestone: for official Nuxeo release <br>  - misc: to demonstrate new feature performance <br>  - continuous: the weekly benchmark on master <br>  - workbench: temporary tests <br>  - custom: custom benchmarks |

The build result (the run) is then published on the https://benchmarks.nuxeo.com/ site 
under the `category` section.

The section lists benchmarks ordered by reverse `benchsuite` names.
For a `benchsuite` the list of run ordered by "$dbprofile $nbnodes $buildid",
and the name displayed will contain the `classifier`.


### Continuous (Weekly) benchmarks
A benchmark suite is triggered every Monday on the master branch.

You can find the results at the following location:
https://benchmarks.nuxeo.com/continuous/index.html

There is a CI Job that schedule the benchmark suite:
https://qa.nuxeo.org/jenkins/job/Misc/job/trigger-nuxeo-reference-bench/

The variation for each run will be on `dbprofile` and one with `mongodb` and `kafka` without Redis.

### Milestone

Milestone benchmarks are done on new Nuxeo release.
The results are published here: https://benchmarks.nuxeo.com/milestone/index.html

The benchmark suite is composed of the same run as with the weekly benchmarks, using the job:
https://qa.nuxeo.org/jenkins/job/Misc/job/trigger-nuxeo-reference-bench/

And some scalability tests are done using MongoDB and PostgreSQL using 1, 3 and 4 Nuxeo nodes.
Theses extra run are scheduled using the following job:
https://qa.nuxeo.org/jenkins/job/Misc/job/trigger-nuxeo-reference-bench-milestone/

### Misc Benchmark

You can use the reference benchmark to measure the performance impact for the feature.
 
For instance to test the impact of the feature Foo:
 - you have a jira ticket NXP-1234
 - you have a branch feature-NXP-1234-foo
 - the parent branch is master
 
#### Run a first benchmark on your branch
 
|parameter| value | description |
| --- | ---: | --- |
| `benchsuite` | `19w39 NXP-1234 Foo` | 19w39 means 2019 week #39 |
| `classifier` | Foo impl | This is the run with the feature activated |
| `category` | `misc` | The results will be stored in the Misc section. |
| `dbprofile` | `mongodb` | The backend used for the document repository |
| `distribution` | `feature-NXP-1234-foo/master` | The Nuxeo distribution to use (must be >= 8.1):|

Keep all other default parameters.

#### Run a reference benchmark on master

|parameter| value | description |
| --- | ---: | --- |
| `benchsuite` | `19w39 NXP-1234 Foo` | 19w39 means 2019 week #39 |
| `classifier` | reference | The classifier for the run |
| `category` | `misc` | The results will be stored in the Misc section. |
| `dbprofile` | `mongodb` | The backend used for the document repository |
| `distribution` | `feature-NXP-1234-foo/master` | The Nuxeo distribution to use (must be >= 8.1):|
 
#### Analyze

The results of the 2 builds will be published on:

https://benchmarks.nuxeo.com/misc/index.html

You can compare the results of feature Foo vs reference with the help of details reports that contain monitoring capture.

You can write your analysis in the NXP ticket but it is also possible to add it directly on the site:

```bash
git clone git@github.com:nuxeo/nuxeo-bench-site.git
cd nuxeo-bench-site

vi data/analysis/suite.yml
```

The `suite.yml` file contains all benchmarks analysis. Add your analysis on the top of the file:

```bash
"19w39 NXP-1234 Foo": "Foo feature analysis, the key must match the benchsuite

- This is normal markdown.
"
```

Visit the [README](https://github.com/nuxeo/nuxeo-bench-site/blob/master/README.md) if you want to generate locally the site for verification.

Then commit and push your change, the site will be updated automatically within few minutes.


### Site publication flow

After a reference benchmark build is run, the following job is executed to publish details reports into a s3 bucket and add benchmarks results in nuxeo-bench-site git repository:
https://qa.nuxeo.org/jenkins/job/Misc/job/nuxeo-reference-site-add/

The update of the [site git repository](https://github.com/nuxeo/nuxeo-bench-site) triggers the static site build and publish the results in another s3 bucket:  
https://qa.nuxeo.org/jenkins/job/Misc/job/nuxeo-reference-site/

Note that there is also the `deploy-nuxeo.com-benchmarks` job to deploy the final version on https://benchmarks.nuxeo.com/.


# About Nuxeo

Nuxeo provides a modular, extensible, open source
[platform for enterprise content management](http://www.nuxeo.com/products/content-management-platform) used by organizations worldwide to power business processes and content repositories in the area of
[document management](http://www.nuxeo.com/solutions/document-management),
[digital asset management](http://www.nuxeo.com/solutions/digital-asset-management),
[case management](http://www.nuxeo.com/case-management) and [knowledge management](http://www.nuxeo.com/solutions/advanced-knowledge-base/). Designed
by developers for developers, the Nuxeo platform offers a modern
architecture, a powerful plug-in model and top notch performance.

More information on: <http://www.nuxeo.com/>
