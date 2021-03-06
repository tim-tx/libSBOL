%module libsbol
%{
    #define SWIG_FILE_WITH_INIT

    //  Headers are listed in strict order of dependency
    #include "constants.h"
    #include "sbolerror.h"
    #include "config.h"
    #include "validation.h"
    #include "property.h"
    #include "properties.h"
    #include "object.h"
    #include "identified.h"
    #include "toplevel.h"
    #include "sequenceannotation.h"
    #include "component.h"
    #include "componentdefinition.h"
    #include "sequence.h"
    #include "document.h"
    #include "interaction.h"
    #include "participation.h"
    #include "location.h"
    #include "sequenceconstraint.h"
    #include "moduledefinition.h"
    #include "module.h"

    #include "mapsto.h"
    #include "model.h"
    #include "collection.h"
    #include "provo.h"
    #include "partshop.h"
    #include "combinatorialderivation.h"
    #include "dbtl.h"
    #include "attachment.h"
    #include "implementation.h"
    #include "sbol.h"

    #include <vector>
    #include <map>
    #include <unordered_map>

    using namespace sbol;
    using namespace std;
    
%}
%include "python_docs.i"

#ifdef SWIGWIN
    %include <windows.i>
#endif

// I was never successful in getting typemap(in) to convert a Python list argument into C++ types, so I hacked these helper functions to perform the conversion
%{
    std::vector<std::string> convert_list_to_string_vector(PyObject *list)
    {
        if (!PyList_Check(list))
            throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "First argument must be a List of ComponentDefinition objects or Strings containing their displayIds");
        if (PyList_Size(list) == 0)
            return {};
        PyObject *obj = PyList_GetItem(list, 0);
        std::vector<std::string> list_of_cpp_strings;
        if (PyUnicode_Check(obj))
        {
            // Convert Python 3 strings
            for (int i = 0; i < PyList_Size(list); ++i)
            {
                obj = PyList_GetItem(list, i);
                PyObject* bytes = PyUnicode_AsUTF8String(obj);
                std::string cpp_string = PyBytes_AsString(bytes);
                list_of_cpp_strings.push_back(cpp_string);
            }
        }
        else if (PyBytes_Check(obj))
        {
            // Convert Python 2 strings
            for (int i = 0; i < PyList_Size(list); ++i)
            {
                obj = PyList_GetItem(list, i);
                std::string cpp_string = PyBytes_AsString(obj);
                list_of_cpp_strings.push_back(cpp_string);
            }
        }
        return list_of_cpp_strings;
    }
    
    std::vector<sbol::ComponentDefinition*> convert_list_to_cdef_vector(PyObject *list)
    {
        if (!PyList_Check(list))
            throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "First argument must be a List of ComponentDefinition objects or Strings containing their displayIds");
        if (PyList_Size(list) == 0)
            return {};
        PyObject *obj;
        std::vector<sbol::ComponentDefinition*> list_of_cdefs = {};
        sbol::ComponentDefinition* cd;
        for (int i = 0; i < PyList_Size(list); ++i)
        {
            obj = PyList_GetItem(list, i);
            if ((SWIG_ConvertPtr(obj,(void **) &cd, SWIG_TypeQuery("sbol::ComponentDefinition*"),1)) == -1) break;
            list_of_cdefs.push_back(cd);
        }
        return list_of_cdefs;
    }

    std::vector<sbol::Identified*> convert_list_to_identified_vector(PyObject *list)
    {
        if (!PyList_Check(list))
            throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "First argument must be a List of ComponentDefinition objects or Strings containing their displayIds");
        if (PyList_Size(list) == 0)
            return {};
        PyObject *py_obj = PyList_GetItem(list, 0);
        std::vector<sbol::Identified*> identified_vector = {};
        sbol::Identified* sbol_obj;
        if (SWIG_IsOK(SWIG_ConvertPtr(py_obj,(void **) &sbol_obj, SWIG_TypeQuery("sbol::Identified*"),1)))
        {
            for (int i = 0; i < PyList_Size(list); ++i)
            {
                py_obj = PyList_GetItem(list, i);
                if ((SWIG_ConvertPtr(py_obj,(void **) &sbol_obj, SWIG_TypeQuery("sbol::Identified*"),1)) == -1) throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "Usages must be a valid SBOL object");;
                identified_vector.push_back(sbol_obj);
            }
        }
        return identified_vector;
    }
%}





//  General error handling and mapping of libSBOL exception types to Python exception types
%exception {
    try
    {
        $function
    }
    catch(SBOLError e)
    {
        if (e.error_code() == SBOL_ERROR_NOT_FOUND)
        {
            PyErr_SetString(PyExc_LookupError, e.what());
        }
        else if (e.error_code() == SBOL_ERROR_INVALID_ARGUMENT || e.error_code() == SBOL_ERROR_MISSING_DOCUMENT)
        {
            PyErr_SetString(PyExc_ValueError, e.what());
        }
        else if (e.error_code() == SBOL_ERROR_TYPE_MISMATCH)
        {
            PyErr_SetString(PyExc_TypeError, e.what());
        }
        else if (e.error_code() == SBOL_ERROR_FILE_NOT_FOUND)
        {
            PyErr_SetString(PyExc_IOError, e.what());
        }
        else
        {
            PyErr_SetString(PyExc_RuntimeError, e.what());
        }
        return NULL;
    }
    catch(...)
    {
        PyErr_SetString(PyExc_RuntimeError, "An error of unspecified type occurred");
    }
}

// Catch the signal from the Python interpreter indicating that iteration has reached end of list. For Python 2
%exception next
{
    try
    {
        $action
    }
    catch(SBOLError e)
    {
        PyErr_SetNone(PyExc_StopIteration);
        return NULL;
    }
}

// Catch the signal from the Python interpreter indicating that iteration has reached end of list. For Python 3
%exception __next__
{
    try
    {
        $action
    }
    catch(SBOLError e)
    {
        PyErr_SetNone(PyExc_StopIteration);
        return NULL;
    }
}

// Hide these methods in the Python API
%ignore sbol::SBOLObject::close;
%ignore sbol::SBOLObject::properties;
%ignore sbol::SBOLObject::list_properties;
%ignore sbol::SBOLObject::owned_objects;
%ignore sbol::SBOLObject::begin;
// %ignore sbol::SBOLObject::end;
%ignore sbol::SBOLObject::size;
%ignore sbol::Property::begin;
%ignore sbol::Property::end;
%ignore sbol::Property::size;

%ignore sbol::OwnedObject::begin;
%ignore sbol::OwnedObject::end;
%ignore sbol::OwnedObject::size;
%ignore sbol::ReferencedObject::begin;
%ignore sbol::ReferencedObject::end;
%ignore sbol::ReferencedObject::size;
%ignore sbol::Document::parse_objects;
%ignore sbol::Document::parse_properties;
%ignore sbol::Document::namespaceHandler;
%ignore sbol::Document::flatten();
%ignore sbol::Document::parse_objects;
%ignore sbol::Document::close;
%ignore sbol::ComponentDefinition::assemble(std::vector<std::string> list_of_uris, Document& doc);  // Use variant signature defined in this interface file
%ignore sbol::ComponentDefinition::assemble(std::vector<std::string> list_of_uris);  // Use variant signature defined in this interface file
%ignore sbol::ComponentDefinition::linearize(std::vector<std::string> list_of_uris);  // Use variant signature defined in this interface file
%ignore sbol::TopLevel::addToDocument;

// Instantiate STL templates
%include "std_string.i"
%include "std_vector.i"
%include "std_map.i"


// This typemap is here in order to convert the return type of ComponentDefinition::getPrimaryStructure into a Python list. (The typemaps defined later in this file work on other methods, but did not work on this method specifically)
%typemap(out) std::vector < sbol::ComponentDefinition* > {
    int len = $1.size();
    PyObject* list = PyList_New(0);
    for(auto i_elem = $1.begin(); i_elem != $1.end(); i_elem++)
    {
        ComponentDefinition* cd = *i_elem;
        PyObject *elem = SWIG_NewPointerObj(SWIG_as_voidptr(*i_elem), $descriptor(sbol::ComponentDefinition*), 0 |  0 );
        PyList_Append(list, elem);
    }
    $result  = list;
    $1.clear();
    PyErr_Clear();
}


// Typemap the hash table returned by Analysis::report methods
%typemap(out) std::unordered_map < std::string, std::tuple < int, int, float > > {
    int len = $1.size();
    PyObject* dict = PyDict_New();
    for(auto & i_elem : $1)
    {
        std::tuple < int, int, float > vals = i_elem.second;
        int range_start = std::get<0>(vals);
        int range_end = std::get<1>(vals);
        float qc_stat = std::get<2>(vals);
        PyObject* py_vals = Py_BuildValue("iif", range_start, range_end, qc_stat);
        PyDict_SetItemString(dict, i_elem.first.c_str(), py_vals);
    }
    $result  = dict;
    $1.clear();
    
}

%template(_IntVector) std::vector<int>;
%template(_StringVector) std::vector<std::string>;
%template(_SBOLObjectVector) std::vector<sbol::SBOLObject*>;
%template(_MapVector) std::map<std::string, std::string >;
%template(_MapOfStringVector) std::map<std::string, std::vector<std::string> >;
%template(_MapOfSBOLObject) std::map<std::string, std::vector< sbol::SBOLObject* > >;


// Instantiate libSBOL templates
%include "config.h"
%include "constants.h"
%include "validation.h"
%include "property.h"

%template(_StringProperty) sbol::Property<std::string>;  // These template instantiations are private, hence the underscore...
%template(_IntProperty) sbol::Property<int>;
%template(_FloatProperty) sbol::Property<double>;

%pythonappend add
%{
    try:
        sbol_obj.thisown = False
    except NameError:
        try:
            if not type(args[0]) == str:
                args[0].thisown = False
        except NameError:
            pass
%}

%pythonappend set
%{
    try:
        sbol_obj.thisown = False
    except NameError:
        try:
            if not type(args[0]) == str:
                args[0].thisown = False
        except NameError:
            pass
%}
    
%pythonappend create
%{
    val.thisown = False
%}
    
// verifyTarget acts like a setter
%pythonappend verifyTarget
%{
    consensus_sequence.thisown = False
%}
    
/* @TODO remove methods should change thisown flag back to True */
/* Currently this causes an exception (probably need a call to Py_INCREF */
//%pythonprepend remove
//%{
//    print ("Getting " + args[0])
//    obj = self.get(args[0])
//    obj.thisown = True
//%}
    
%pythonappend getAll
%{
    val = list(val)
%}

//%pythonappend addToDocument
//%{
//    print("Adding to Document")
//    arg2.thisown = False
//%}
    
    
%include "properties.h"
%include "object.h"
%include "identified.h"
%include "toplevel.h"
%include "location.h"
%include "sequenceannotation.h"
%include "mapsto.h"
%include "component.h"
%include "sequenceconstraint.h"
%include "componentdefinition.h"
%include "sequence.h"
%include "participation.h"
%include "interaction.h"
%include "module.h"
%include "model.h"
%include "collection.h"
%include "moduledefinition.h"
%include "provo.h"
%include "combinatorialderivation.h"
%include "attachment.h"
%include "implementation.h"
%include "dbtl.h"

// Converts json-formatted text into Python data structures, eg, lists, dictionaries
%pythonappend sbol::PartShop::search
%{
    if val[0] == '[' :
        exec('val = ' + val)
        return val
    else :
        return val
%}
//
//// Converts json-formatted text into Python data structures, eg, lists, dictionaries
%pythonappend sbol::PartShop::submit
%{
    if val[0] == '[' :
        exec('val = ' + val)
        return val
    else :
        return val
%}

%pythonappend sbol::PartShop::searchRootCollections
%{
    true = True
    false = False
    exec('val = ' + val)
    return val
%}

%pythonappend sbol::PartShop::searchSubCollections
%{
    true = True
    false = False
    exec('val = ' + val)
    return val
%}
    
%include "partshop.h"
    
%include "document.h"

typedef std::string sbol::sbol_type;

/* This macro is used to instantiate container properties (OwnedObjects) that can contain more than one type of object, eg, SequenceAnnotation::locations */
%define TEMPLATE_MACRO_0(SBOLClass)
//    %template(add ## SBOLClass) sbol::OwnedObject::add<SBOLClass>;
    %template(create ## SBOLClass) sbol::OwnedObject::create<SBOLClass>;
    %template(get ## SBOLClass) sbol::OwnedObject::get<SBOLClass>;
    
%enddef

/* This macro is used to instantiate container properties (OwnedObjects) that can contain a single type of object, eg, ComponentDefinition::sequenceAnnotations */
%define TEMPLATE_MACRO_1(SBOLClass)
    
    /* Convert C++ vector of pointers --> Python list */
    %typemap(out) std::vector<sbol::SBOLClass*> {
        int len = $1.size();
        PyObject* list = PyList_New(0);
        for(auto i_elem = $1.begin(); i_elem != $1.end(); i_elem++)
        {
            PyObject *elem = SWIG_NewPointerObj(SWIG_as_voidptr(*i_elem), $descriptor(sbol::SBOLClass*), 0 |  0 );
            PyList_Append(list, elem);
        }
        $result  = list;
        $1.clear();
    }
    
    %extend sbol::OwnedObject<sbol::SBOLClass >
    {
        PyObject* __getitem__(const int nIndex)
        {
            SBOLClass& obj = $self->operator[](nIndex);
            PyObject *py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(&obj), $descriptor(sbol::SBOLClass*), 0 |  0 );
            return py_obj;
        }
        
        PyObject* __getitem__(const std::string uri)
        {
            SBOLClass& obj = $self->operator[](uri);
            PyObject *py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(&obj), $descriptor(sbol::SBOLClass*), 0 |  0 );
            return py_obj;
        }
        
        void __setitem__(const std::string uri, PyObject* py_obj)
        {
            sbol:: SBOLClass* obj;
            if ((SWIG_ConvertPtr(py_obj,(void **) &obj, $descriptor(sbol:: SBOLClass *),1)) == -1) throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "Invalid object type for this property");
            $self->add(*obj);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            if (uri == obj->identity.get() || uri  == obj->displayId.get())
                return;
            else
                throw SBOLError(SBOL_ERROR_INVALID_ARGUMENT, "Cannot add " + parseClassName(obj->type) + ". The given URIs do not match");
        }
    }
    
    /* Instantiate templates */
    %template(SBOLClass ## Vector) std::vector<sbol::SBOLClass>;
    %template(SBOLClass ## Property) sbol::Property<sbol::SBOLClass >;
    %template(Owned ## SBOLClass) sbol::OwnedObject<sbol::SBOLClass >;

%enddef

/* This macro is used to instantiate special adders and getters for the Document class */
%define TEMPLATE_MACRO_2(SBOLClass)

    %extend sbol::SBOLClass
    {
        SBOLClass& copy(Document* target_doc = NULL, std::string ns = "", std::string version = "")
        {
            return $self->copy < SBOLClass >(target_doc, ns, version);
        }
    }
    
    %pythonappend add ## SBOLClass
    %{
        if type(args[0]) is list:
            for obj in args[0]:
                obj.thisown = False
        else:
            args[0].thisown = False
    %}
    
    %template(add ## SBOLClass) sbol::Document::add<SBOLClass>;
    %template(get ## SBOLClass) sbol::Document::get<SBOLClass>;
    %extend sbol::Document
    {
        void add ## SBOLClass(PyObject *list)
        {
            std::vector<sbol:: SBOLClass *> list_of_cds = {};
            if (PyList_Check(list))
            {
                for (int i = 0; i < PyList_Size(list); ++i)
                {
                    PyObject *obj = PyList_GetItem(list, i);
                    sbol:: SBOLClass * cd;
                    if ((SWIG_ConvertPtr(obj,(void **) &cd, $descriptor(sbol:: SBOLClass *),1)) == -1) throw;
                    list_of_cds.push_back(cd);
                }
                $self->add(list_of_cds);
            };        
        }
    }
    
%enddef

/* This macro is used to create a Pythonic interface to object attributes */
%define TEMPLATE_MACRO_3(SBOLClass)
%extend sbol::SBOLClass {

%pythoncode {

    def __getattribute__(self,name):
        if name in object.__getattribute__(self, '__swig_getmethods__').keys():
            sbol_attribute = object.__getattribute__(self, name)
            if not 'Owned' in sbol_attribute.__class__.__name__:
                if sbol_attribute.getUpperBound() != '1':
                    return sbol_attribute.getAll()
                else:
                    try:
                        return sbol_attribute.get()
                    except LookupError:
                        return None
                return None
            elif sbol_attribute.getUpperBound() == '1':
                try:
                    return sbol_attribute.get()
                except:
                    return None
        return object.__getattribute__(self, name)
            
    __setattribute__ = __setattr__
            
    def __setattr__(self,name, value):
        if name in object.__getattribute__(self, '__swig_setmethods__').keys():
            sbol_attribute = object.__getattribute__(self, name)
            if not 'Owned' in sbol_attribute.__class__.__name__:
                if value == None:
                    sbol_attribute.clear()
                elif type(value) == list:
                    if sbol_attribute.getUpperBound() == '1':
                        raise TypeError('The ' + sbol_attribute.getTypeURI() + ' property does not accept list arguments')
                    sbol_attribute.clear()
                    for val in value:
                        sbol_attribute.add(val)
                else:
                    sbol_attribute.set(value)
            elif sbol_attribute.getUpperBound() == '1':
                if len(sbol_attribute) > 0:
                    sbol_obj = sbol_attribute.get()
                    doc = sbol_obj.doc
                    sbol_attribute.remove()
                    if not doc:
                        sbol_obj.thisown = True
                    elif not doc.find(sbol_obj.identity):
                        sbol_obj.thisown = True
                if not value == None:
                    sbol_attribute.set(value)
                    value.thisown = False
        else:
            self.__class__.__setattribute__(self, name, value)

    def __repr__(self):
        return self.__class__.__name__
    
}
}
%enddef
    
// Dynamically type Locations
%extend sbol::OwnedObject<sbol::Location >
{
    PyObject* __getitem__(const std::string uri)
    {
        Location& obj = (Location&)$self->operator[](uri);
        PyObject* py_obj;
        if (obj.type == SBOL_RANGE)
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(&obj), $descriptor(sbol::Range*), 0 |  0 );
        else if (obj.type == SBOL_CUT)
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(&obj), $descriptor(sbol::Cut*), 0 |  0 );
        else if (obj.type == SBOL_GENERIC_LOCATION)
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(&obj), $descriptor(sbol::GenericLocation*), 0 |  0 );
        else
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(&obj), $descriptor(sbol::Location*), 0 |  0 );
        return py_obj;
    }
    
    void __setitem__(const std::string uri, PyObject* py_obj)
    {
        Range* range;
        Cut* cut;
        GenericLocation* genericlocation;
        Location* location;
        Identified* obj;
        
        if ((SWIG_ConvertPtr(py_obj,(void **) &range, $descriptor(sbol::Range *),1)) != -1)
        {
            $self->add((Location&)*range);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)range;
        }
        else if ((SWIG_ConvertPtr(py_obj,(void **) &cut, $descriptor(sbol::Cut *),1)) != -1)
        {
            $self->add((Location&)*cut);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)cut;
        }
        else if ((SWIG_ConvertPtr(py_obj,(void **) &genericlocation, $descriptor(sbol::GenericLocation *),1)) != -1)
        {
            $self->add((Location&)*genericlocation);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)genericlocation;
        }
        else if ((SWIG_ConvertPtr(py_obj,(void **) &location, $descriptor(sbol::Location *),1)) != -1)
        {
            $self->add(*location);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)location;
        }
        else
            throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "Invalid object type for this property");
        if (uri == obj->identity.get() || uri  == obj->displayId.get())
            return;
        else
            throw SBOLError(SBOL_ERROR_INVALID_ARGUMENT, "Cannot add " + parseClassName(obj->type) + ". The given URIs do not match");
    }
}
    
// Dynamically type Interactions
%extend sbol::OwnedObject<sbol::Interaction >
{
    PyObject* __getitem__(const std::string uri)
    {
        Interaction* obj = &($self->operator[](uri));
        PyObject* py_obj;
        if (dynamic_cast<TranscriptionalRepressionInteraction*>(obj))
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(obj), $descriptor(sbol::TranscriptionalRepressionInteraction*), 0 |  0 );
        else if (dynamic_cast<SmallMoleculeInhibitionInteraction*>(obj))
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(obj), $descriptor(sbol::SmallMoleculeInhibitionInteraction*), 0 |  0 );
        else if (dynamic_cast<GeneProductionInteraction*>(obj))
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(obj), $descriptor(sbol::GeneProductionInteraction*), 0 |  0 );
        else if (dynamic_cast<TranscriptionalActivationInteraction*>(obj))
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(obj), $descriptor(sbol::TranscriptionalActivationInteraction*), 0 |  0 );
        else if (dynamic_cast<SmallMoleculeActivationInteraction*>(obj))
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(obj), $descriptor(sbol::SmallMoleculeActivationInteraction*), 0 |  0 );
        else
            py_obj = SWIG_NewPointerObj(SWIG_as_voidptr(obj), $descriptor(sbol::Interaction*), 0 |  0 );
        return py_obj;
    }

    void __setitem__(const std::string uri, PyObject* py_obj)
    {
        TranscriptionalRepressionInteraction* transcriptionalrepressioninteraction;
        SmallMoleculeInhibitionInteraction* smallmoleculeinhibitioninteraction;
        GeneProductionInteraction* geneproductioninteraction;
        TranscriptionalActivationInteraction* transcriptionalactivationinteraction;
        SmallMoleculeActivationInteraction* smallmoleculeactivationinteraction;
        Interaction* interaction;
        Identified* obj;
        if ((SWIG_ConvertPtr(py_obj,(void **) &transcriptionalrepressioninteraction, $descriptor(sbol::TranscriptionalRepressionInteraction *),1)) != -1)
        {
            $self->add((Interaction&)*transcriptionalrepressioninteraction);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)transcriptionalrepressioninteraction;
        }
        else if ((SWIG_ConvertPtr(py_obj,(void **) &smallmoleculeinhibitioninteraction, $descriptor(sbol::SmallMoleculeInhibitionInteraction *),1)) != -1)
        {
            $self->add((Interaction&)*smallmoleculeinhibitioninteraction);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)smallmoleculeinhibitioninteraction;
        }
        else if ((SWIG_ConvertPtr(py_obj,(void **) &geneproductioninteraction, $descriptor(sbol::GeneProductionInteraction *),1)) != -1)
        {
            $self->add((Interaction&)*geneproductioninteraction);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)geneproductioninteraction;
        }
        else if ((SWIG_ConvertPtr(py_obj,(void **) &transcriptionalactivationinteraction, $descriptor(sbol::TranscriptionalActivationInteraction *),1)) != -1)
        {
            $self->add((Interaction&)*transcriptionalactivationinteraction);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)transcriptionalactivationinteraction;
        }
        else if ((SWIG_ConvertPtr(py_obj,(void **) &smallmoleculeactivationinteraction, $descriptor(sbol::SmallMoleculeActivationInteraction *),1)) != -1)
        {
            $self->add((Interaction&)*smallmoleculeactivationinteraction);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)smallmoleculeactivationinteraction;
        }
        else if ((SWIG_ConvertPtr(py_obj,(void **) &interaction, $descriptor(sbol::Interaction *),1)) != -1)
        {
            $self->add((Interaction&)*interaction);
            int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            obj = (Identified*)interaction;
        }
        else
            throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "Invalid object type for this property");
        if (uri == obj->identity.get() || uri  == obj->displayId.get())
            return;
        else
            throw SBOLError(SBOL_ERROR_INVALID_ARGUMENT, "Cannot add " + parseClassName(obj->type) + ". The given URIs do not match");
    }
}
    
// Templates used by subclasses of Location: Range, Cut, and Generic Location
TEMPLATE_MACRO_0(Range);
TEMPLATE_MACRO_0(Cut);
TEMPLATE_MACRO_0(GenericLocation);

// Templates used in SequenceAnnotation class
TEMPLATE_MACRO_1(Location);
        
// Templates used in Component class
TEMPLATE_MACRO_1(MapsTo);
     
// Templates used in ComponentDefinition class
TEMPLATE_MACRO_1(SequenceConstraint);
TEMPLATE_MACRO_1(SequenceAnnotation);
TEMPLATE_MACRO_1(Component);

// Templates used in Participation class
//%template(listOfURIs) sbol::List<sbol::URIProperty>;

// Templates used in Interaction class
TEMPLATE_MACRO_1(Participation);
        
// ModuleDefinition templates
TEMPLATE_MACRO_1(Module);
TEMPLATE_MACRO_1(Interaction);
TEMPLATE_MACRO_1(FunctionalComponent);
    
// Templates used in Activity class
TEMPLATE_MACRO_1(Association);
TEMPLATE_MACRO_1(Usage);
  
// Templates used in ComponentDerivation class
TEMPLATE_MACRO_1(VariableComponent);

// Templates classes used by Document class
TEMPLATE_MACRO_1(ComponentDefinition);
TEMPLATE_MACRO_1(ModuleDefinition);
TEMPLATE_MACRO_1(Sequence);
TEMPLATE_MACRO_1(Model);
TEMPLATE_MACRO_1(Collection);
TEMPLATE_MACRO_1(Activity);
TEMPLATE_MACRO_1(Plan);
TEMPLATE_MACRO_1(Agent);
TEMPLATE_MACRO_1(Attachment);
TEMPLATE_MACRO_1(Implementation);
TEMPLATE_MACRO_1(CombinatorialDerivation);
TEMPLATE_MACRO_1(Design);
TEMPLATE_MACRO_1(Build);
TEMPLATE_MACRO_1(Test);
TEMPLATE_MACRO_1(Analysis);
TEMPLATE_MACRO_1(SampleRoster);

TEMPLATE_MACRO_2(ComponentDefinition)
TEMPLATE_MACRO_2(ModuleDefinition)
TEMPLATE_MACRO_2(Sequence)
TEMPLATE_MACRO_2(Model)
TEMPLATE_MACRO_2(Collection)
TEMPLATE_MACRO_2(Activity);
TEMPLATE_MACRO_2(Plan);
TEMPLATE_MACRO_2(Agent);
TEMPLATE_MACRO_2(Attachment);
TEMPLATE_MACRO_2(Implementation);
TEMPLATE_MACRO_2(CombinatorialDerivation);
TEMPLATE_MACRO_2(Design);
TEMPLATE_MACRO_2(Build);
TEMPLATE_MACRO_2(Test);
TEMPLATE_MACRO_2(Analysis);
TEMPLATE_MACRO_2(SampleRoster);
    
TEMPLATE_MACRO_3(SBOLObject)
TEMPLATE_MACRO_3(Identified)
TEMPLATE_MACRO_3(ComponentDefinition)
TEMPLATE_MACRO_3(SequenceAnnotation)
TEMPLATE_MACRO_3(SequenceConstraint)
TEMPLATE_MACRO_3(Location)
TEMPLATE_MACRO_3(Range)
TEMPLATE_MACRO_3(Cut)
TEMPLATE_MACRO_3(ModuleDefinition)
TEMPLATE_MACRO_3(Module)
TEMPLATE_MACRO_3(FunctionalComponent)
TEMPLATE_MACRO_3(Interaction)
TEMPLATE_MACRO_3(Participation)
TEMPLATE_MACRO_3(Component)
TEMPLATE_MACRO_3(MapsTo)
TEMPLATE_MACRO_3(Model)
TEMPLATE_MACRO_3(Sequence)
TEMPLATE_MACRO_3(Collection)
TEMPLATE_MACRO_3(Attachment)
TEMPLATE_MACRO_3(Implementation)
TEMPLATE_MACRO_3(CombinatorialDerivation)
TEMPLATE_MACRO_3(Activity)
TEMPLATE_MACRO_3(Agent)
TEMPLATE_MACRO_3(Plan)
TEMPLATE_MACRO_3(Usage)
TEMPLATE_MACRO_3(Design)
TEMPLATE_MACRO_3(Build)
TEMPLATE_MACRO_3(Test)
TEMPLATE_MACRO_3(Analysis)
TEMPLATE_MACRO_3(SearchQuery);
TEMPLATE_MACRO_3(SampleRoster);
TEMPLATE_MACRO_3(TranscriptionalRepressionInteraction);
TEMPLATE_MACRO_3(SmallMoleculeInhibitionInteraction);
TEMPLATE_MACRO_3(GeneProductionInteraction);
TEMPLATE_MACRO_3(TranscriptionalActivationInteraction);
TEMPLATE_MACRO_3(SmallMoleculeActivationInteraction);
TEMPLATE_MACRO_3(EnzymeCatalysisInteraction);
TEMPLATE_MACRO_3(Document);
    
// Template functions used by PartShop
//%template(pullComponentDefinitionFromCollection) sbol::PartShop::pull < ComponentDefinition > (sbol::Collection& collection);
%template(pullComponentDefinition) sbol::PartShop::pull < ComponentDefinition >;
%template(pullCollection) sbol::PartShop::pull < Collection >;
%template(pullSequence) sbol::PartShop::pull < Sequence >;
//%template(pullDocument) sbol::PartShop::pull < Document >;
%template(countComponentDefinition) sbol::PartShop::count < ComponentDefinition >;
%template(countCollection) sbol::PartShop::count < Collection >;

// Used to create alias properties for FunctionalComponents used in the design-build-test-learn module
%template(AliasedOwnedFunctionalComponent) sbol::AliasedProperty<sbol::FunctionalComponent >;

    
%include "assembly.h"
    
%extend sbol::ComponentDefinition
{
    
    void assemble(PyObject *list, PyObject *doc)
    {
        sbol::Document* cpp_doc;
        if ((SWIG_ConvertPtr(doc,(void **) &cpp_doc, $descriptor(sbol::Document*),1)) == -1)
            throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "Second argument must be a valid Document");
        std::vector<sbol::ComponentDefinition*> list_of_cdefs = convert_list_to_cdef_vector(list);
        if (list_of_cdefs.size())
        {
            $self->assemble(list_of_cdefs, *cpp_doc);
            return;
        }
        return;
    };
    
    void assemble(PyObject *list)
    {
        std::vector<std::string> list_of_display_ids = convert_list_to_string_vector(list);
        if (list_of_display_ids.size())
        {
            $self->assemble(list_of_display_ids);
            return;
        }
        std::vector<sbol::ComponentDefinition*> list_of_cdefs = convert_list_to_cdef_vector(list);
        if (list_of_cdefs.size())
        {
            $self->assemble(list_of_cdefs);
            return;
        }
        return;
    }

    void assemblePrimaryStructure(PyObject *list, PyObject *doc)
    {
        sbol::Document* cpp_doc;
        if ((SWIG_ConvertPtr(doc,(void **) &cpp_doc, $descriptor(sbol::Document*),1)) == -1)
            throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "Second argument must be a valid Document");
        std::vector<sbol::ComponentDefinition*> list_of_cdefs = convert_list_to_cdef_vector(list);
        if (list_of_cdefs.size())
        {
            $self->assemblePrimaryStructure(list_of_cdefs, *cpp_doc);
            return;
        }
        return;
    }
    
    void assemblePrimaryStructure(PyObject *list)
    {
        std::vector<std::string> list_of_display_ids = convert_list_to_string_vector(list);
        if (list_of_display_ids.size())
        {
            $self->assemblePrimaryStructure(list_of_display_ids);
            return;
        }
        std::vector<sbol::ComponentDefinition*> list_of_cdefs = convert_list_to_cdef_vector(list);
        if (list_of_cdefs.size())
        {
            $self->assemblePrimaryStructure(list_of_cdefs);
            return;
        }
        return;
    }
    
    void linearize(PyObject *list)
    {
        std::vector<std::string> list_of_display_ids = convert_list_to_string_vector(list);
        if (list_of_display_ids.size())
        {
            $self->linearize(list_of_display_ids);
            return;
        }
        std::vector<sbol::ComponentDefinition*> list_of_cdefs = convert_list_to_cdef_vector(list);
        if (list_of_cdefs.size())
        {
            $self->linearize(list_of_cdefs);
            return;
        }
        return;
    }
    
    
    bool isRegular(PyObject* py_string)
    {
        std::string msg;
        bool IS_REGULAR;
        IS_REGULAR = $self->isRegular(msg);
        py_string = PyUnicode_FromString(msg.c_str());
        return IS_REGULAR;
    };
}
    
%extend sbol::Document
{
    PyObject* getExtensionObject(std::string id)
    {
        // Search the Document's object store for the uri
        if ($self->PythonObjects.find(id) != $self->PythonObjects.end())
        {
            PyObject* py_obj = $self->PythonObjects[id];
            Py_INCREF(py_obj);
            return py_obj;
        }
        throw SBOLError(NOT_FOUND_ERROR, "Object " + id + " not found");
    }
    
    void addExtensionObject(PyObject* py_obj)
    {
        typedef struct {
            PyObject_HEAD
            void *ptr; // This is the pointer to the actual C++ instance
            void *ty;  // swig_type_info originally, but shouldn't matter
            int own;
            PyObject *next;
        } SwigPyObject;
        
        // Get pointer to wrapped object
        SwigPyObject* swig_py_object = (SwigPyObject*)PyObject_GetAttr(py_obj,  PyUnicode_FromString("this"));
        if (swig_py_object)
        {
            SBOLObject* sbol_obj = (SBOLObject *)swig_py_object->ptr;
            TopLevel* tl = dynamic_cast<TopLevel*>(sbol_obj);
            if (tl)
            {
                tl->doc = $self;
                tl->parent = $self;
                $self->SBOLObjects[$self->identity.get()] = tl;
                $self->PythonObjects[sbol_obj->identity.get()] = py_obj;
                int check = PyObject_SetAttr(py_obj, PyUnicode_FromString("thisown"), Py_False);
            }
            // Call the add method to recursively add child objects and set their back-pointer to this Document
            for (auto i_store = sbol_obj->owned_objects.begin(); i_store != sbol_obj->owned_objects.end(); ++i_store)
            {
                std::vector<SBOLObject*>& object_store = i_store->second;
                for (auto i_obj = object_store.begin(); i_obj != object_store.end(); ++i_obj)
                {
                    $self->add<SBOLObject>(**i_obj);
                }
            }
        }
        else
            throw SBOLError(SBOL_ERROR_TYPE_MISMATCH, "Not a valid SBOL object");
    }
    
    Document* __iter__()
    {
        $self->python_iter = Document::iterator($self->SBOLObjects.begin());
        return $self;
    }
    
    SBOLObject* next()
    {
        if ($self->python_iter != $self->end())
        {
            SBOLObject& obj = *self->python_iter;
            $self->python_iter++;
            if ($self->python_iter == $self->end())
            {
                PyErr_SetNone(PyExc_StopIteration);
            }
            return &obj;
        }
        throw SBOLError(END_OF_LIST, "");
        return NULL;
    }
    
    SBOLObject* __next__()
    {
        if ($self->python_iter != $self->end())
        {
            
            SBOLObject& obj = *$self->python_iter;
            $self->python_iter++;
            return &obj;
        }
        
        throw SBOLError(END_OF_LIST, "");;
        return NULL;
    }
    
    int __len__()
    {
        return $self->size();
    }
    
}

    
%extend sbol::ModuleDefinition
{
    void assemble(PyObject *list)
    {
        std::vector<sbol::ModuleDefinition*> list_of_mdefs = {};
        if (PyList_Check(list))
        {
            for (int i = 0; i < PyList_Size(list); ++i)
            {
                PyObject *obj = PyList_GetItem(list, i);
                sbol::ModuleDefinition* md;
                if ((SWIG_ConvertPtr(obj,(void **) &md, $descriptor(sbol::ModuleDefinition*),1)) == -1) throw;
                list_of_mdefs.push_back(md);
            }
            $self->assemble(list_of_mdefs);
        };
    }
}

%extend sbol::SearchQuery
{
    sbol::TextProperty __getitem__(std::string uri)
    {
        return $self->operator[](uri);
    }
    
}

%extend sbol::SearchResponse
{
    sbol::Identified& __getitem__(int i)
    {
        return $self->operator[](i);
    }
    
    int __len__()
    {
        return $self->size();
    }
    
    SearchResponse* __iter__()
    {
        $self->python_iter = SearchResponse::iterator($self->begin());
        return $self;
    }
    
    Identified* next()
    {
        if ($self->python_iter != $self->end())
        {
            Identified* obj = *$self->python_iter;
            $self->python_iter++;
            if ($self->python_iter == $self->end())
            {
                PyErr_SetNone(PyExc_StopIteration);
            }
            return obj;
        }
        throw SBOLError(END_OF_LIST, "");
        return NULL;
    }
    
    Identified* __next__()
    {
        if ($self->python_iter != $self->end())
        {
            
            Identified* obj = *$self->python_iter;
            $self->python_iter++;
            
            return obj;
        }
        
        throw SBOLError(END_OF_LIST, "");;
        return NULL;
    }
}

    
%extend sbol::TopLevel
{
    PyObject* generateDesign(std::string uri, Agent& agent, Plan& plan, PyObject* usage_list)
    {
        std::vector < Identified* > usage_vector = convert_list_to_identified_vector(usage_list);
        Design& design = $self->generate<Design>(uri, agent, plan, usage_vector);
        return SWIG_NewPointerObj(SWIG_as_voidptr(&design), $descriptor(sbol::Design*), 0 |  0 );
    }
    
    PyObject* generateBuild(std::string uri, Agent& agent, Plan& plan, PyObject* usage_list)
    {
        std::vector < Identified* > usage_vector = convert_list_to_identified_vector(usage_list);
        Build& build = $self->generate<Build>(uri, agent, plan, usage_vector);
        return SWIG_NewPointerObj(SWIG_as_voidptr(&build), $descriptor(sbol::Build*), 0 |  0 );
    }
    
    PyObject* generateTest(std::string uri, Agent& agent, Plan& plan, PyObject* usage_list)
    {
        std::vector < Identified* > usage_vector = convert_list_to_identified_vector(usage_list);
        Test& test = $self->generate<Test>(uri, agent, plan, usage_vector);
        return SWIG_NewPointerObj(SWIG_as_voidptr(&test), $descriptor(sbol::Test*), 0 |  0 );
    }
    
    PyObject* generateAnalysis(std::string uri, Agent& agent, Plan& plan, PyObject* usage_list)
    {
        std::vector < Identified* > usage_vector = convert_list_to_identified_vector(usage_list);
        Analysis& analysis = $self->generate<Analysis>(uri, agent, plan, usage_vector);
        return SWIG_NewPointerObj(SWIG_as_voidptr(&analysis), $descriptor(sbol::Analysis*), 0 |  0 );
    }
}
    
%extend sbol::EnzymeCatalysisInteraction
{
    EnzymeCatalysisInteraction(std::string uri, ComponentDefinition& enzyme, PyObject* substrates, PyObject* products)
    {
        std::vector<ComponentDefinition*> substrate_v = convert_list_to_cdef_vector(substrates);
        std::vector<ComponentDefinition*> product_v = convert_list_to_cdef_vector(products);
        EnzymeCatalysisInteraction(uri, enzyme, substrate_v, product_v, {}, {});
    }

    
    EnzymeCatalysisInteraction(std::string uri, ComponentDefinition& enzyme, PyObject* substrates, PyObject* products, PyObject* cofactors, PyObject* sideproducts)
    {
        std::vector<ComponentDefinition*> substrate_v = convert_list_to_cdef_vector(substrates);
        std::vector<ComponentDefinition*> product_v = convert_list_to_cdef_vector(products);
        std::vector<ComponentDefinition*> cofactor_v = convert_list_to_cdef_vector(cofactors);
        std::vector<ComponentDefinition*> sideproduct_v = convert_list_to_cdef_vector(sideproducts);
        EnzymeCatalysisInteraction(uri, enzyme, substrate_v, product_v, cofactor_v, sideproduct_v);
    }
}
    
%template(generateDesign) sbol::TopLevel::generate<Design>;
%template(generateBuild) sbol::TopLevel::generate<Build>;
%template(generateTest) sbol::TopLevel::generate<Test>;
%template(generateAnalysis) sbol::TopLevel::generate<Analysis>;

    
%pythonbegin %{
from __future__ import absolute_import
%}
    
%pythoncode
%{
    def applyToComponentHierarchy(self, callback_fn, user_data):
        # Assumes parent_component is an SBOL data structure of the general form ComponentDefinition(->Component->ComponentDefinition)n where n+1 is an integer describing how many hierarchical levels are in the SBOL structure
        # Look at each of the ComponentDef's SequenceAnnotations, is the target base there?
        if not self.doc:
            raise Exception('Cannot traverse Component hierarchy without a Document')
    
        GET_ALL = True
        component_nodes = []
        if len(self.components) == 0:
            component_nodes.append(self)  # Add leaf components
            if (callback_fn):
                callback_fn(self, user_data)
        else:
            if GET_ALL:
                component_nodes.append(self)  # Add components with children
                if callback_fn:
                    callback_fn(self, user_data)
            for subc in self.components:
                if not self.doc.find(subc.definition.get()):
                    raise Exception(subc.definition.get() + 'not found')
                subcdef = self.doc.getComponentDefinition(subc.definition.get())
                subcomponents = subcdef.applyToComponentHierarchy(callback_fn, user_data)
                component_nodes.extend(subcomponents)
        return component_nodes

    
    ComponentDefinition.applyToComponentHierarchy = applyToComponentHierarchy
    
    
    def testSBOL():
        """
        Function to run test suite for pySBOL
        """
        import sbol.unit_tests as unit_tests
        unit_tests.runTests()
            
    def is_extension_property(obj, name):
        attribute_dict = object.__getattribute__(obj, '__dict__')
        if name in attribute_dict:
            if type(attribute_dict[name]) in [ TextProperty, URIProperty, IntProperty, FloatProperty, ReferencedObject, DateTimeProperty, VersionProperty ] :
                return True
        return False

    def is_swig_property(obj, name):
        swig_attribute_dict = object.__getattribute__(obj, '__swig_getmethods__')
        if name in swig_attribute_dict:
            return True
        return False

    class PythonicInterface(object):

        def __getattribute__(self,name):
            sbol_attribute = None
            if is_swig_property(self, name):
                sbol_attribute = object.__getattribute__(self, name)
            elif is_extension_property(self, name):
                sbol_attribute = object.__getattribute__(self, '__dict__')[name]
            if sbol_attribute:
                if not 'Owned' in sbol_attribute.__class__.__name__:
                    if sbol_attribute.getUpperBound() != '1':
                        return sbol_attribute.getAll()
                    else:
                        try:
                            return sbol_attribute.get()
                        except LookupError:
                            return None
                    return None
                elif sbol_attribute.getUpperBound() == '1':
                    try:
                        return sbol_attribute.get()
                    except:
                        return None
            return object.__getattribute__(self, name)

        def __setattr__(self,name, value):
            sbol_attribute = None
            if is_swig_property(self, name):
                sbol_attribute = object.__getattribute__(self, name)
            elif is_extension_property(self, name):
                sbol_attribute = object.__getattribute__(self, '__dict__')[name]
            if sbol_attribute:
                if not 'Owned' in sbol_attribute.__class__.__name__:
                    if value == None:
                        sbol_attribute.clear()
                    elif type(value) == list:
                        if sbol_attribute.getUpperBound() == '1':
                            raise TypeError('The ' + sbol_attribute.getTypeURI() + ' property does not accept list arguments')
                        sbol_attribute.clear()
                        for val in value:
                            sbol_attribute.add(val)
                    else:
                        sbol_attribute.set(value)
                elif sbol_attribute.getUpperBound() == '1':
                    if len(sbol_attribute) > 0:
                        sbol_obj = sbol_attribute.get()
                        doc = sbol_obj.doc
                        sbol_attribute.remove()
                        if not doc:
                            sbol_obj.thisown = True
                        elif not doc.find(sbol_obj.identity):
                            sbol_obj.thisown = True
                    if not value == None:
                        sbol_attribute.set(value)
                        value.thisown = False
            else:
                self.__class__.__setattribute__(self, name, value)

            def __repr__(self):
                return self.__class__.__name__
%}
    

        
        //%extend sbol::Document
        //{
        //    std::string __getitem__(const int nIndex)
        //    {
        //        return $self->operator[](nIndex);
        //    }
        //
        //    ReferencedObject* __iter__()
        //    {
        //        $self->python_iter = Document::iterator($self->begin());
        //        return $self;
        //    }
        //
        //    std::string next()
        //    {
        //        if ($self->python_iter != $self->end())
        //        {
        //            std::string ref = *$self->python_iter;
        //            $self->python_iter++;
        //            if ($self->python_iter == $self->end())
        //            {
        //                PyErr_SetNone(PyExc_StopIteration);
        //            }
        //            return ref;
        //        }
        //        throw (END_OF_LIST);
        //        return NULL;
        //    }
        //    
        //    int __len__()
        //    {
        //        return $self->size();
        //    }
        //};
        
        

//// The following code was experimented with for mapping C++ class structure to Python class structure
//%pythonappend ComponentDefinition %{
//    name = property(name.set, name.get)
//    %}
//
//%extend sbol::Identified{
//    %pythoncode %{
//        __swig_getmethods__["identity"] = _libsbol.TextProperty.get
//        __swig_setmethods__["identity"] = _libsbol.TextProperty.set
//        if _newclass: identity = property(_libsbol.TextProperty.get, _libsbol.URIProperty.set)
//            %}
//};

//%include "std_unordered_map.i"
//namespace std {
//    %template(_UnorderedMapVector) unordered_map<string, string >;
//    //%template(_UnorderedMapOfStringVector) unordered_map<string, string>;
//}
        
//%include "std_function.i"
//namespace std {
//    %template(_ValidationRule) function<void(void *, void *)>;
//    %template(_ValidationRules) vector<function<void(void *, void *)>>;}
//}
        
//typedef const void(*sbol::ValidationRule)(void *, void *);
// %template(_ValidationRules) std::vector<sbol::ValidationRule>;
        
//%pythonappend sbol::Config::parse_extension_objects()
//%{
//    print ("Parsing extension objects")
//%}
//
//%pythonappend sbol::Config::extension_memory_handler(bool swig_thisown)
//%{
//    print ("Entering memory handler")
//    print (args)
//    self.thisown = args[0]
//%}
        
//%pythonappend sbol::Config::extension_memory_handler(bool swig_thisown)
//%{
//    print ("Entering memory handler")
//    print (args)
//    self.thisown = args[0]
//%}




