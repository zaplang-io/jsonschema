#!/usr/bin/env python3
"""Prepare an offline corpus without changing upstream schemas or expectations."""
import json
from pathlib import Path
from urllib.parse import urljoin, urldefrag
root=Path(__file__).resolve().parent.parent
suite=root/'vendor/test-suite'
resources={}
retrievals={}
for path in (suite/'remotes').rglob('*.json'):
    uri='http://localhost:1234/'+str(path.relative_to(suite/'remotes'))
    resources[uri]=json.loads(path.read_text()); retrievals[uri]=uri
for path in (root/'vendor/metaschemas').glob('*.json'):
    doc=json.loads(path.read_text()); uri=doc['$id'].rstrip('#'); resources[uri]=doc; retrievals[uri]=uri
# Lookup canonical aliases, while retaining original resource contents.
for uri,doc in list(resources.items()):
    if isinstance(doc,dict) and isinstance(doc.get('$id'),str):
        alias=urljoin(uri,doc['$id']).rstrip('#')
        if alias not in resources:
            resources[alias]=doc;retrievals[alias]=uri
def closure(schema):
    found={};queue=[(schema,'')];seen=set()
    def walk(value,base):
        if isinstance(value,dict):
            if isinstance(value.get('$id'),str):base=urljoin(base,value['$id'])
            for keyword in ['$ref','$dynamicRef','$recursiveRef','$schema']:
                ref=value.get(keyword)
                if isinstance(ref,str):
                    uri=urldefrag(urljoin(base,ref))[0]
                    if uri in resources and uri not in seen:
                        # Standard meta-schemas are used internally for checks;
                        # explicit $refs still require them in the registry.
                        if keyword=='$schema' and uri.startswith(('https://json-schema.org/','http://json-schema.org/')):continue
                        seen.add(uri);retrieval=retrievals[uri];found[retrieval]=resources[uri];queue.append((resources[uri],retrieval))
            for v in value.values():walk(v,base)
        elif isinstance(value,list):
            for v in value:walk(v,base)
    while queue:
        doc,base=queue.pop(0);walk(doc,base)
    return found
out=root/'tests/conformance';out.mkdir(exist_ok=True)
manifest={}
for draft in ['draft7','draft2019-09','draft2020-12']:
    groups=[]
    for file in sorted((suite/'tests'/draft).glob('*.json')):
        for group in json.loads(file.read_text()):
            groups.append({'name':file.name+': '+group['description'],'schema':group['schema'],'registry':closure(group['schema']),'tests':group['tests']})
    (out/(draft+'.json')).write_text(json.dumps(groups,ensure_ascii=False,separators=(',',':'))+'\n')
    skipped=[]
    for file in sorted((suite/'tests'/draft/'optional').rglob('*.json')):
        count=sum(len(group['tests']) for group in json.loads(file.read_text()))
        skipped.append({'path':str(file.relative_to(suite/'tests'/draft)),'cases':count,'reason':'optional behavior not claimed; see support documentation'})
    manifest[draft]={'required_groups':len(groups),'required_cases':sum(len(g['tests']) for g in groups),'optional_skips':skipped}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({d:{k:v for k,v in m.items() if k!='optional_skips'} for d,m in manifest.items()}))
