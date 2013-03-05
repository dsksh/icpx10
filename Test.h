#ifndef __TEST_H
#define __TEST_H

#include <x10rt.h>


namespace x10 { namespace array { 
template<class TPMGL(T)> class Array;
} } 
namespace x10 { namespace lang { 
class String;
} } 
class Test : public x10::lang::X10Class   {
    public:
    RTT_H_DECLS_CLASS
    
    static void main(x10::array::Array<x10::lang::String*>* argv);
    virtual Test* Test____this__Test();
    void _constructor();
    
    static Test* _make();
    
    
    // Serialization
    public: static const x10aux::serialization_id_t _serialization_id;
    
    public: virtual x10aux::serialization_id_t _get_serialization_id() {
         return _serialization_id;
    }
    
    public: virtual void _serialize_body(x10aux::serialization_buffer& buf);
    
    public: static x10::lang::Reference* _deserializer(x10aux::deserialization_buffer& buf);
    
    public: void _deserialize_body(x10aux::deserialization_buffer& buf);
    
};

#endif // TEST_H

class Test;

#ifndef TEST_H_NODEPS
#define TEST_H_NODEPS
#ifndef TEST_H_GENERICS
#define TEST_H_GENERICS
#endif // TEST_H_GENERICS
#endif // __TEST_H_NODEPS
