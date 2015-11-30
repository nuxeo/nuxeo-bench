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

