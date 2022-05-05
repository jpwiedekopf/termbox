CALL apoc.load.json("file:///termbox-demo-codesystem.json")
//CALL apoc.load.json("file:///oncotree-2020-10-01.json")
YIELD value AS fhir_cs

WITH fhir_cs, "u=" + fhir_cs.url + "|" + "v=" + fhir_cs.version + "|" + "m=" + coalesce(fhir_cs.meta.version, 1) AS ns
//create node for CS
MERGE (cs:CodeSystem {ns: ns, url: fhir_cs.url, version: fhir_cs.version, meta_version: coalesce(fhir_cs.meta.version, 1)})
  SET cs.meta_last_updated = timestamp()

//add the attributes to another node, copy attributes by key
WITH fhir_cs, ns, cs, ["name", "title", "status", "date", "publisher", "description", "purpose", "copyright", "caseSensitive", "hierarchyMeaning", "compositional", "versionNeeded", "content", "supplements", "count"] AS cs_attr_keys
  MERGE (cs)-[:HAS_CODESYSTEM_ATTRIBUTES]->(cs_attr:CodeSystemAttributes {ns: ns})
    SET cs_attr += apoc.map.fromLists(cs_attr_keys, apoc.map.values(fhir_cs, cs_attr_keys, true))
    SET 
      cs_attr.contact = CASE WHEN fhir_cs.contact IS NULL THEN null ELSE apoc.convert.toJson(fhir_cs.contact) END, 
      cs_attr.identifier = CASE WHEN fhir_cs.identifier IS NULL THEN null ELSE apoc.convert.toJson(fhir_cs.identifier) END, 
      cs_attr.useContext = CASE WHEN fhir_cs.useContext IS NULL THEN null ELSE apoc.convert.toJson(fhir_cs.useContext) END

//attach the implicit VS to the CS
WITH fhir_cs, ns, cs, cs_attr UNWIND fhir_cs.valueSet as valueSet
  MERGE (vs_i:ImplicitValueSet:ValueSet {ns: ns, url: valueSet})-[:VALUESET_CONTAINS_ALL]->(cs)

//create properties
WITH fhir_cs, ns, cs, ["uri", "description"] AS prop_keys 
  UNWIND fhir_cs.property AS fhir_prop
    MERGE (cs)-[:DEFINES_PROPERTY]->(prop:Property {ns: ns, code: fhir_prop.code, type: fhir_prop.type})
      SET prop += apoc.map.fromLists(prop_keys, apoc.map.values(fhir_prop, prop_keys, true))

// //create filters
// WITH fhir_cs, cs
//   UNWIND fhir_cs.filter AS fhir_filter
//     MERGE (cs)-[:DEFINES_FILTER]->(filt:Filter {ns: ns, code: fhir_filter.code, operator: apoc.convert.toJson(fhir_filter.operator), value: fhir_filter.value})
//       SET filt.description = fhir_filter.description

//create concepts
WITH fhir_cs, ns, cs, ["display", "definition"] AS concept_keys
  UNWIND fhir_cs.concept as fhir_concept
    MERGE (concept:Concept {ns: ns, code: fhir_concept.code})-[:DEFINED_IN]->(cs)
      SET concept += apoc.map.fromLists(concept_keys, apoc.map.values(fhir_concept, concept_keys, true))
      SET concept.designation = CASE WHEN fhir_concept.designation IS NULL THEN null ELSE apoc.convert.toJson(fhir_concept.designation) END
      WITH ns, cs, fhir_concept, concept, ["valueCode", "valueCoding", "valueString", "valueInteger", "valueBoolean", "valueDateTime", "valueDecimal"] AS prop_value_keys
        UNWIND CASE WHEN fhir_concept.property IS null THEN [] ELSE fhir_concept.property END AS fhir_prop //concept.property might be null
          MATCH (source_concept:Concept {ns: ns, code: fhir_concept.code})
          CALL apoc.do.case(
            [
              fhir_prop.code = 'parent', "MATCH (target_concept:Concept {ns: ns, code: fhir_prop.valueCode}) MERGE (source_concept)-[:HAS_PARENT {code: 'parent'}]->(target_concept)",
              fhir_prop.code = 'child', "MATCH (target_concept:Concept {ns: ns, code: fhir_prop.valueCode}) MERGE (target_concept)-[:HAS_PARENT {code: 'child'}]->(source_concept)"
            ],
            "MATCH (target_prop:Property {ns: ns, code: fhir_prop.code}) MERGE (source_concept)-[p:HAS_PROPERTY]->(target_prop) SET p += apoc.map.fromLists(prop_value_keys, apoc.map.values(fhir_prop, prop_value_keys, true))",
            {fhir_prop: fhir_prop, source_concept: source_concept, prop_value_keys: prop_value_keys, ns: ns}
          ) YIELD value
WITH cs
RETURN cs