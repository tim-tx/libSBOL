/**
 * @file    attachment.h
 * @brief   Attachment class
 * @author  Bryan Bartley
 * @email   bartleyba@sbolstandard.org
 *
 * <!--------------------------------------------------------------------------
 * This file is part of libSBOL.  Please visit http://sbolstandard.org for more
 * information about SBOL, and the latest version of libSBOL.
 *
 *  Copyright 2016 University of Washington, WA, USA
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ------------------------------------------------------------------------->*/

#ifndef ATTACHMENT_INCLUDED
#define ATTACHMENT_INCLUDED

#include "toplevel.h"

namespace sbol
{
    /// The Attachment class is a general container for data files, especially experimental data files. Attachment is a TopLevel object, and any other TopLevel object can refer to a list of attachments.
	class SBOL_DECLSPEC Attachment : public TopLevel
	{
	public:
        /// The source is a link to the external file and is REQUIRED.
		URIProperty source;
        
        // The format is an ontology term indicating the format of the file. It is RECOMMENDED to use the EDAM ontology for file formats, which includes a variety of experimental data formats. The format is an OPTIONAL field
        URIProperty format;

        // The size is a long integer indicating the file size in bytes. This may be used by client applications accessing files over RESTful APIs. This field is OPTIONAL.
        IntProperty size;

        // The hash is a string used to retrieve files from a cache. This field is OPTIONAL.
        TextProperty hash;

        /// Construct an Attachment
        /// @param uri A full URI including a scheme, namespace, and identifier.  If SBOLCompliance configuration is enabled, then this argument is simply the displayId for the new object and a full URI will automatically be constructed.
        /// @param source A file URI
        Attachment(std::string uri = "example", std::string source = "", std::string version = "1.0.0") : Attachment(SBOL_ATTACHMENT, uri, source, version) {};

        virtual ~Attachment() {};
	protected:
        Attachment(sbol_type type, std::string uri, std::string source, std::string version) :
            TopLevel(type, uri, version),
            source(SBOL_SOURCE, this, source),
            format(SBOL_URI "#format", this),
            size(SBOL_URI "#size", this),
            hash(SBOL_URI "#hash", this)
            {
            };

	};
}

#endif