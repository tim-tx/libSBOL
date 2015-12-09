#ifndef SEQUENCE_CONSTRAINT_INCLUDED
#define SEQUENCE_CONSTRAINT_INCLUDED

#include "identified.h"

namespace sbol
{
	class SequenceConstraint : public Identified
	{
	public:
		ReferencedObject subject;
		ReferencedObject object;
		URIProperty restriction;

		SequenceConstraint(std::string uri_prefix = SBOL_URI "/SequenceConstraint", std::string id = "example") :
			SequenceConstraint(SBOL_SEQUENCE_CONSTRAINT, uri_prefix, id)
			{
			}
		~SequenceConstraint();
	
	protected:
		SequenceConstraint(sbol_type type, std::string uri_prefix, std::string id) :
			Identified(type, uri_prefix, id, "", "", ""),
			subject(SBOL_SUBJECT, this, UNDEFINED),
			object(SBOL_OBJECT, this, UNDEFINED),
			restriction(SBOL_RESTRICTION, this, UNDEFINED)
			{
			}
	};
}

#endif