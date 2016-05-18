#ifndef PROPERTY_INCLUDED
#define PROPERTY_INCLUDED

#include "constants.h"
#include "sbolerror.h"
#include "validation.h"

#include <raptor2.h>
#include <string>
#include <vector>
#include <iostream>
#include <map>
#include <unordered_map>

/// @defgroup extension_layer Extension layer
/// These classes are not a usual part of the SBOL core data model.  Rather they can be used to define new extension classes which add custom data to the SBOL file format.
 
namespace sbol
{
    /// @brief This string type is assigned URI strings (see constants.h for default values).  This URI controls the tags of RDF/XML nodes
	typedef std::string sbol_type;

	/* All SBOLProperties have a pointer back to the object which the property belongs to.  
	This requires forward declaration of the SBOLObject class */
	class SBOLObject;


    /// @ingroup extension_layer
    /// @brief metafunction for generation of a map of message types to
    /// their associated callbacks.
    /// @details
    /// Usage: Use <tt>generate_callback_map<Type>::type</tt> to ...
    /// @tparam LiteralType The library currently supports Property<string> and Property<int> specification currently supports integer, string, and URI literals
    ///
	template <class LiteralType>
	class Property
	{

	protected:
		sbol_type type;
		SBOLObject *sbol_owner;  // back pointer to the SBOLObject to which this Property belongs
		ValidationRules validationRules;

	public:
        Property(sbol_type type_uri, void *property_owner, std::string initial_value, ValidationRules validation_rules = {});

		Property(sbol_type type_uri, void *property_owner, int initial_value, ValidationRules validation_rules = {});

		Property(sbol_type type_uri = UNDEFINED, void *property_owner = NULL, ValidationRules validation_rules = {}) :
			type(type_uri),
			sbol_owner((SBOLObject *)property_owner),
            validationRules(validation_rules)
		{
		}
		~Property();
		virtual sbol_type getTypeURI();
		virtual SBOLObject& getOwner();
		virtual std::string get();
		void add(std::string new_value);

   		virtual void set(std::string new_value);
		virtual void set(int new_value);
		virtual void write();
		void validate(void * arg = NULL);
        
        std::string operator[] (const int nIndex);

#ifdef SWIG
    protected:
#endif
        class iterator : public std::vector<std::string>::iterator
        {
        public:
            
            iterator(typename std::vector<std::string>::iterator i_str = std::vector<std::string>::iterator()) : std::vector<std::string>::iterator(i_str)
            {
            }
        };
        
        iterator begin()
        {
            std::vector<std::string> *object_store = &this->sbol_owner->properties[this->type];
            return iterator(object_store->begin());
        };
        
        iterator end()
        {
            std::vector<std::string> *object_store = &this->sbol_owner->properties[this->type];
            return iterator(object_store->end());
        };
        
        int size()
        {
            std::size_t size = this->sbol_owner->owned_objects[this->type].size();
            return (int)size;
        };
        
        std::vector<std::string>::iterator python_iter;
    };
    


	/* Constructor for string Property */
	template <class LiteralType>
	Property<LiteralType>::Property(sbol_type type_uri, void *property_owner, std::string initial_value, ValidationRules validation_rules) : Property(type_uri, property_owner, validation_rules)
	{
		// Register Property in owner Object
		if (this->sbol_owner != NULL)
		{
			std::vector<std::string> property_store;
			property_store.push_back(initial_value);
			this->sbol_owner->properties.insert({ type_uri, property_store });
		}
	}

	/* Constructor for int Property */
	template <class LiteralType>
	Property<LiteralType>::Property(sbol_type type_uri, void *property_owner, int initial_value, ValidationRules validation_rules) : Property(type_uri, property_owner, validation_rules)
	{
		// Register Property in owner Object
		if (this->sbol_owner != NULL)
		{
			std::vector<std::string> property_store;
			property_store.push_back("\"" + std::to_string(initial_value) + "\"");
			this->sbol_owner->properties.insert({ type_uri, property_store });
		}
	}


	//typedef std::map<sbol_type, PropertyBase> PropertyStore;

	//extern PropertyStore* global_property_buffer;

    template <class LiteralType>
    Property<LiteralType>::~Property()
    {
    };
    
    
    template <class LiteralType>
    sbol_type Property<LiteralType>::getTypeURI()
    {
        return type;
    }
    
    template <class LiteralType>
    SBOLObject& Property<LiteralType>::getOwner()
    {
        return *sbol_owner;
    }
    
    template <class LiteralType>
    std::string Property<LiteralType>::get()
    {
        if (this->sbol_owner)
        {
            if (this->sbol_owner->properties.find(type) == this->sbol_owner->properties.end())
            {
                // not found
                return "";
            }
            else
            {
                // found
                std::string value = this->sbol_owner->properties[type].front();
                value = value.substr(1, value.length() - 2);  // Strips angle brackets from URIs and quotes from literals
                return value;
            }
        }	else
        {
            return "";
        }
    };
 
    template <class LiteralType>
    std::string Property<LiteralType>::operator[] (const int nIndex)
    {
        std::vector<std::string> *value_store = &this->sbol_owner->properties[this->type];
        return value_store->at(nIndex);
    };
    
    template <class LiteralType>
    void Property<LiteralType>::set(std::string new_value)
    {
        if (sbol_owner)
        {
            //sbol_owner->properties[type].push_back( new_value );
            std::string current_value = this->sbol_owner->properties[this->type][0];
            if (current_value[0] == '<')  //  this property is a uri
            {
                this->sbol_owner->properties[this->type][0] = "<" + new_value + ">";
            }
            else if (current_value[0] == '"') // this property is a literal
            {
                this->sbol_owner->properties[this->type][0] = "\"" + new_value + "\"";
            }
            
        }
        validate((void *)&new_value);
    };
    
    template <class LiteralType>
    void Property<LiteralType>::set(int new_value)
    {
        if (new_value)
        {
            // TODO:  need to convert new_value to string
            this->sbol_owner->properties[type][0] = "\"" + std::to_string(new_value) + "\"";
        }
        validate((void *)&new_value);  //  Call validation rules associated with this Property
    };
    
    template <class LiteralType>
    void Property<LiteralType>::write()
    {
        std::string subject = (*this->sbol_owner).identity.get();
        sbol_type predicate = type;
        std::string object = this->sbol_owner->properties[type].front();
        
        std::cout << "Subject:  " << subject << std::endl;
        std::cout << "Predicate: " << predicate << std::endl;
        std::cout << "Object: "  << std::endl;
    };
    
    template <class LiteralType>
    void Property<LiteralType>::validate(void * arg)
    {
        for (ValidationRules::iterator i_rule = validationRules.begin(); i_rule != validationRules.end(); ++i_rule)
        {
            ValidationRule& validate_fx = *i_rule;
            validate_fx(sbol_owner, arg);
        }
    };
    
    template <class LiteralType>
    void Property<LiteralType>::add(std::string new_value)
    {
        if (sbol_owner)
        {
            std::string current_value = this->sbol_owner->properties[this->type][0];
            if (current_value[0] == '<')  //  this property is a uri
            {
                this->sbol_owner->properties[this->type].push_back("<" + new_value + ">");
            }
            else if (current_value[0] == '"') // this property is a literal
            {
                this->sbol_owner->properties[this->type].push_back("\"" + new_value + "\"");
            }
            validate((void *)&new_value);  //  Call validation rules associated with this Property
        }
    };
    
    
}








#endif
