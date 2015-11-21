#include "document.h"

#include <iostream>
#include <string>
#include <functional>
#include <vector>
#include <unordered_map>
#include <raptor2.h>

using namespace sbol;
using namespace std;

unordered_map<string, SBOLObject&(*)()> sbol::SBOL_DATA_MODEL_REGISTER =
{
	// Typecast proxy constructors to a constructor for SBOL
	// This makes some ugly syntax, but library users should never see it.
	make_pair(UNDEFINED, &create<SBOLObject>),
	make_pair(SBOL_COMPONENT_DEFINITION, (SBOLObject&(*)()) &create<ComponentDefinition>),
	make_pair(SBOL_SEQUENCE_ANNOTATION, (SBOLObject&(*)()) &create<SequenceAnnotation>)

};

void Document::parse_objects(void* user_data, raptor_statement* triple)
{
	Document *doc = (Document *)user_data;

	string subject = reinterpret_cast<char*>(raptor_term_to_string(triple->subject));
	string predicate = reinterpret_cast<char*>(raptor_term_to_string(triple->predicate));
	string object = reinterpret_cast<char*>(raptor_term_to_string(triple->object));
	
	subject = subject.substr(1, subject.length() - 2);  // Removes flanking < and > from uri
	predicate = predicate.substr(1, predicate.length() - 2);  // Removes flanking < and > from uri
	object = object.substr(1, object.length() - 2);  // Removes flanking < and > from uri
	cout << subject << "\t" << predicate << "\t" << object << endl;

	// Triples that have a predicate matching the following uri signal to the parser that a new SBOL object should be constructred
	if (predicate.compare("http://www.w3.org/1999/02/22-rdf-syntax-ns#type") == 0)
	{
		// Checks if the object has already been created and whether a constructor for this type of object exists
		if ((doc->SBOLObjects.count(subject) == 0) && (SBOL_DATA_MODEL_REGISTER.count(object) == 1))
		{

			SBOLObject& new_obj = SBOL_DATA_MODEL_REGISTER[ object ]();
			new_obj.identity.set(subject);

			// All created objects are placed in the document's object store.  However, only toplevel objects will be left permanently.
			// Owned objects are kept in the object store as a temporary convenience and will be removed later.
			doc->add<SBOLObject>(new_obj);

		}
	}

}

void Document::parse_properties(void* user_data, raptor_statement* triple)
{
	Document *doc = (Document *)user_data;

	string subject = reinterpret_cast<char*>(raptor_term_to_string(triple->subject));
	string predicate = reinterpret_cast<char*>(raptor_term_to_string(triple->predicate));
	string object = reinterpret_cast<char*>(raptor_term_to_string(triple->object));



	string id = subject.substr(1, subject.length() - 2);  // Removes flanking < and > from the uri
	string property_uri = predicate.substr(1, predicate.length() - 2);  // Removes flanking < and > from uri
	string property_value = object.substr(1, object.length() - 2);  // Removes flanking " from literal

	std::size_t found = property_uri.find('#');
	if (found != std::string::npos)
	{
		string property_ns = property_uri.substr(0, found);
		string property_name = property_uri.substr(found + 1, subject.length() - 1);
		// If property name is something other than "type" than the triple matches the pattern for defining properties

		if (property_name.compare("type") != 0)
		{
			// Checks if the object to which this property belongs already exists
			if (doc->SBOLObjects.find(id) != doc->SBOLObjects.end())
			{
				TopLevel *sbol_obj = doc->SBOLObjects[id];
				cout << "Parsing " << property_uri <<  endl;

				// Decide if this triple corresponds to a simple property, a list property, an owned property or a referenced property
				if (sbol_obj->properties.find(property_uri) != sbol_obj->properties.end())
				{
					if (property_name.compare("persistentIdentity") == 0)
					{
						cout << subject << predicate << object << endl;
						getchar();
					}
					// TODO: double-check this, is there a memory-leak here?
					sbol_obj->properties[property_uri].clear();
					sbol_obj->properties[property_uri].push_back(property_value);
					cout << "Setting simple property " << property_name << endl;
				}
				else if (sbol_obj->list_properties.find(property_uri) != sbol_obj->list_properties.end())
				{
					sbol_obj->list_properties[property_uri].push_back(property_value);
				}
				else if (sbol_obj->owned_objects.find(property_uri) != sbol_obj->owned_objects.end())
				{
					string owned_obj_id = property_value;
					TopLevel *owned_obj = doc->SBOLObjects[owned_obj_id];
					sbol_obj->owned_objects[property_uri].push_back(owned_obj);
					doc->SBOLObjects.erase(owned_obj_id);
				}
			}
		}
	}
}


void Document::read(std::string filename)
{
	// Wipe existing contents of this Document
	raptor_free_world(this->rdf_graph);  //  Probably need to free other objects as well...
	this->rdf_graph = raptor_new_world();
	SBOLObjects.clear();

	FILE* fh = fopen(filename.c_str(), "rb");
	raptor_parser* rdf_parser = raptor_new_parser(this->rdf_graph, "rdfxml");
	raptor_iostream* ios = raptor_new_iostream_from_file_handle(this->rdf_graph, fh);
	unsigned char *uri_string;
	raptor_uri *uri, *base_uri;
	
	void *user_data = this;
	raptor_parser_set_statement_handler(rdf_parser, user_data, this->parse_objects);
	raptor_uri *sbol_uri = raptor_new_uri(this->rdf_graph, (const unsigned char *)SBOL_URI "#");
	raptor_parser_parse_iostream(rdf_parser, ios, sbol_uri);
	cout << this->SBOLObjects.size() << endl;
	getchar();

	raptor_free_iostream(ios);
	rewind(fh);
	ios = raptor_new_iostream_from_file_handle(this->rdf_graph, fh);
	raptor_parser_set_statement_handler(rdf_parser, user_data, this->parse_properties);
	raptor_parser_parse_iostream(rdf_parser, ios, sbol_uri);

	raptor_free_uri(sbol_uri);
	raptor_free_iostream(ios);
	raptor_free_parser(rdf_parser);

	fclose(fh);

}


void SBOLObject::serialize(raptor_serializer* sbol_serializer, raptor_world *sbol_world)
{
	cout << "Serializing object" << endl;

	// Check if there is an RDF graph associated with this SBOLObject.  Only TopLevel objects can be belong to SBOL Documents, so
	// only TopLevel objects have a valid back-pointer.
	//
	// The only other type of SBOL Object that can serialize besides TopLevel are objects
	// that form a composite with a TopLevel object.  In this case, the TopLevel object will pass the
	// pointer to the RDF graph to its composite objects

	if (doc)
	{
		sbol_world = doc->getWorld();
	}
	if (sbol_world)
	{
		// This RDF triple makes the following statement:
		// "This instance of an SBOL object belongs to class X"
		raptor_statement *triple = raptor_new_statement(sbol_world);
		std::string subject = identity.get();
		std::string predicate = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type";
		std::string object = type;

		triple->subject = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)subject.c_str());
		triple->predicate = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)predicate.c_str());
		triple->object = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)object.c_str());

		cout << subject << predicate << object << endl;

		// Write the triples
		raptor_serializer_serialize_statement(sbol_serializer, triple);

		// Delete the triple 
		raptor_free_statement(triple);

		for (auto it = properties.begin(); it != properties.end(); ++it)
		{

			// This RDF triple makes the following statement:
			// "This SBOL object has a property called X and its value is Y"
			raptor_statement *triple2 = raptor_new_statement(sbol_world);

			//std::string new_predicate = (SBOL_URI "#" + it->first);
			std::string new_predicate = it->first;
			std::string new_object = it->second.front();

			triple2->subject = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)subject.c_str());
			triple2->predicate = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)new_predicate.c_str());
			triple2->object = raptor_new_term_from_literal(sbol_world, (const unsigned char *)new_object.c_str(), NULL, NULL);
			if (new_object.length() > 0 && new_object.front() == '<' && new_object.back() == '>')
			{
				cout << subject << new_predicate << new_object << endl;

				getchar();
			}



			// Write the triples
			raptor_serializer_serialize_statement(sbol_serializer, triple2);

			// Delete the triple 
			raptor_free_statement(triple2);
		}

		// Serialize all properties corresponding to black diamonds in UML diagrams
		// RDF-XML list/container elements
		for (auto i = owned_objects.begin(); i != owned_objects.end(); ++i)
		{
			cout << "Serializing " << owned_objects.size() << " owned_objects" << endl;
			
			// Serialize each object in the object store that belongs to this property
			std::string property_name = i->first;
			vector<SBOLObject*> object_store = i->second;
			
			// This RDF triple makes the following statement:
			// "This instance of an SBOL object has property called X"
			raptor_statement *triple2 = raptor_new_statement(sbol_world);
			subject = identity.get();
			predicate = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type";
			object = property_name;
			
			triple2->subject = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)subject.c_str());
			triple2->predicate = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)predicate.c_str());
			triple2->object = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)object.c_str());
			cout << subject << predicate << object << endl;

			// Write the triple2s
			raptor_serializer_serialize_statement(sbol_serializer, triple2);

			// Delete the triple 
			raptor_free_statement(triple2);

			int i_o = 0;
			for (auto o = object_store.begin(); o != object_store.end(); ++o)
			{
				SBOLObject* obj = *o;
				++i_o;
				cout << obj->type << endl;

				// This RDF triple makes the following statement:
				// "This instance of an SBOL object owns another SBOL object"
				raptor_statement *triple = raptor_new_statement(sbol_world);
				std::string subject = identity.get();
				std::string predicate = property_name;
				std::string object = obj->identity.get();
				
				//std::string subject = property_name;
				//std::string predicate = "http://www.w3.org/1999/02/22-rdf-syntax-ns#_" + std::to_string(i_o);
				//std::string object = obj->identity.get();

				//triple->subject = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)subject.c_str());
				triple->subject = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)subject.c_str());
				triple->predicate = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)predicate.c_str());
				triple->object = raptor_new_term_from_uri_string(sbol_world, (const unsigned char *)object.c_str());

				cout << subject << predicate << object << endl;

				// Write the triples
				raptor_serializer_serialize_statement(sbol_serializer, triple);

				// Delete the triple 
				raptor_free_statement(triple);

				// Recursive call to serialize child objects
				obj->serialize(sbol_serializer, sbol_world);
			}
		}
	}
}

void TopLevel::addToDocument(Document& doc)
{
	//doc.SBOLObjects[this->identity.get()] = this;
	doc.add(*this);
};

TopLevel& Document::getTopLevel(string uri)
{
    // @TODO validate if object is TopLevel or else trigget a libSBOL error
	// @TODO return libSBOL error if URI not found
	return *(this->SBOLObjects[uri]);
};

raptor_world* Document::getWorld()
{
	// @TODO validate if object is TopLevel or else trigget a libSBOL error
	// @TODO return libSBOL error if URI not found
	return (this->rdf_graph);
};

void Document::write(std::string filename)
{

	// Initialize raptor serializer
	FILE* fh = fopen(filename.c_str(), "wb");
	raptor_world* world = getWorld();
	raptor_serializer* sbol_serializer = raptor_new_serializer(world, "rdfxml-abbrev");
	raptor_iostream* ios = raptor_new_iostream_to_file_handle(world, fh);
	raptor_serializer_start_to_iostream(sbol_serializer, NULL, ios);
	raptor_uri *sbol_uri = raptor_new_uri(world, (const unsigned char *)SBOL_URI "#");
	raptor_uri *purl_uri = raptor_new_uri(world, (const unsigned char *)PURL_URI "#");
	const unsigned char *sbol_prefix = (const unsigned char *)"sbol";
	const unsigned char *purl_prefix = (const unsigned char *)"dcterms";
	raptor_namespace_stack *sbol_namespaces = raptor_new_namespaces(world, 0);
	raptor_namespace *sbol_namespace = raptor_new_namespace_from_uri(sbol_namespaces, sbol_prefix, sbol_uri, 1);
	raptor_namespace *purl_namespace = raptor_new_namespace_from_uri(sbol_namespaces, purl_prefix, purl_uri, 1);
	raptor_serializer_set_namespace_from_namespace(sbol_serializer, sbol_namespace);
	raptor_serializer_set_namespace_from_namespace(sbol_serializer, purl_namespace);
	raptor_serializer_start_to_file_handle(sbol_serializer, NULL, fh);
	
	// Iterate through objects in document and serialize them
	for (auto obj_i = SBOLObjects.begin(); obj_i != SBOLObjects.end(); ++obj_i)
	{
		obj_i->second->serialize(sbol_serializer);
	}

	// End serialization 
	raptor_serializer_serialize_end(sbol_serializer);
	raptor_free_serializer(sbol_serializer);
	raptor_free_iostream(ios);
	fclose(fh);
};