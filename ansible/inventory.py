#!/usr/bin/env python

import argparse
import boto.ec2
import json
import os
import pprint
import yaml

abspath = os.path.abspath(__file__)
dirname = os.path.dirname(abspath)
os.chdir(dirname)

f = open("group_vars/all/main.yml", "r")
default = yaml.load(f, Loader=yaml.FullLoader)
f.close()
f = open("group_vars/all/custom.yml", "r")
custom = yaml.load(f, Loader=yaml.FullLoader)
f.close()
region = default["aws_region"]
bench = default["bench"]
dbprofile = custom["dbprofile"]
nosqldbprofile = custom["nosqldbprofile"]
keypair = custom["keypair"]

parser = argparse.ArgumentParser()
parser.add_argument("--hosts", help="List the hosts for the specified group")
parser.add_argument("--list", help="List the whole inventory", action="store_true")
args = parser.parse_args()

ec2 = boto.ec2.connect_to_region(region)
reservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag-key": "bench_role"})
instances = [i for r in reservations for i in r.instances]
dbreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "db", "tag:dbprofile": "*" + dbprofile + "*"})
dbinstances = [i for r in dbreservations for i in r.instances]
nosqldbreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "nosqldb", "tag:dbprofile": "*" + nosqldbprofile + "*"})
nosqldbinstances = [i for r in nosqldbreservations for i in r.instances]
mongodbreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "db", "tag:dbprofile": "*mongodb*"})
mongodbinstances = [i for r in mongodbreservations for i in r.instances]
mgmtreservations = ec2.get_all_instances(filters={"tag:bench": bench, "tag:bench_role": "mgmt"})
mgmtinstances = [i for r in mgmtreservations for i in r.instances]

hostvars = {}
groups = {}

allinstances = []
allids = []
for i in instances + dbinstances + nosqldbinstances + mongodbinstances + mgmtinstances:
    if i.id not in allids:
        allinstances.append(i)
        allids.append(i.id)

for i in allinstances:
    #pprint.pprint (i.__dict__)
    state = i._state.name
    if state != "running":
        continue
    role = i.tags["bench_role"]
    if keypair == "Jenkins":
        address = i.private_ip_address
    else:
        address = i.ip_address
    if role not in groups:
        groups[role] = {"hosts": []}
    if role == "db" and i.tags["dbprofile"].find(dbprofile) == -1:
        pass
    elif role == "nosqldb" and i.tags["dbprofile"].find(nosqldbprofile) == -1:
        pass
    else:
        groups[role]["hosts"].append(address)
    if role == "db" and i.tags["dbprofile"].find("mongodb") != -1:
        if "mongodb" not in groups:
            groups["mongodb"] = {"hosts": []}
        groups["mongodb"]["hosts"].append(address)
    hvars = {}
    hvars["id"] = i.id
    hvars["state"] = state
    hvars["image_id"] = i.image_id
    hvars["public_ip"] = i.ip_address
    hvars["private_ip"] = i.private_ip_address

    hostvars[address] = hvars


inventory = {"_meta": {"hostvars": hostvars}}
inventory.update(groups)

if "nuxeo" not in inventory:
    inventory["nuxeo"] = {}
if "es" not in inventory:
    inventory["es"] = {}
if "kafka" not in inventory:
    inventory["kafka"] = {}
inventory["nuxeo"]["vars"] = {"db_hosts": [], "nosqldb_hosts": [], "es_hosts": [], "mongodb_hosts": [], "mgmt_hosts": [], "kafka_hosts": []}
inventory["es"]["vars"] = {"mgmt_hosts": []}
inventory["kafka"]["vars"] = {"mgmt_hosts": []}
if "db" in groups:
    for i in groups["db"]["hosts"]:
        inventory["nuxeo"]["vars"]["db_hosts"].append(hostvars[i]["private_ip"])
if "nosqldb" in groups:
    for i in groups["nosqldb"]["hosts"]:
        inventory["nuxeo"]["vars"]["nosqldb_hosts"].append(hostvars[i]["private_ip"])
if "es" in groups:
    for i in groups["es"]["hosts"]:
        inventory["nuxeo"]["vars"]["es_hosts"].append(hostvars[i]["private_ip"])
if "mongodb" in groups:
    for i in groups["mongodb"]["hosts"]:
        inventory["nuxeo"]["vars"]["mongodb_hosts"].append(hostvars[i]["private_ip"])
if "mgmt" in groups:
    for i in groups["mgmt"]["hosts"]:
        inventory["nuxeo"]["vars"]["mgmt_hosts"].append(hostvars[i]["private_ip"])
        inventory["es"]["vars"]["mgmt_hosts"].append(hostvars[i]["private_ip"])
        inventory["kafka"]["vars"]["mgmt_hosts"].append(hostvars[i]["private_ip"])
if "kafka" in groups:
    for i in groups["kafka"]["hosts"]:
        inventory["nuxeo"]["vars"]["kafka_hosts"].append(hostvars[i]["private_ip"])

#print inventory

if args.hosts:
    print " ".join(inventory[args.hosts]["hosts"])
else:
    print json.dumps(inventory, sort_keys=True, indent=2)

