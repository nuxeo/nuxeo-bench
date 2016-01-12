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
