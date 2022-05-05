MATCH (conceptA:Concept {ns: $ns_cs_version, code: "ACA"})
MATCH (conceptB:Concept {ns: $ns_cs_version, code: "MIDDA"})
OPTIONAL MATCH p = (conceptA)-[:HAS_PARENT*]->(conceptB)
OPTIONAL MATCH q = (conceptB)-[:HAS_PARENT*]->(conceptA)
RETURN relationships(p) AS paths, relationships(q) AS reverse_paths
// then do this again the other way around
// but what about mixtures of child and parent?
// maybe reduce all parent/child relationships to parent, and store the original code alongside the relationship
// that would allow for simpler queries, and generally, the difference between parent and child is neglegible