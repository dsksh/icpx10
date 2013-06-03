/*************************************************/
/* START of Test */
#include <Test.h>

#include <x10/array/Array.h>
#include <x10/lang/String.h>

//#line 16 "/Users/ishii/workspace/rpx10/Test.x10": x10.ast.X10MethodDecl_c
void Test::main(x10::array::Array<x10::lang::String*>* argv) {
 
}

//#line 6 "/Users/ishii/workspace/rpx10/Test.x10": x10.ast.X10MethodDecl_c
Test* Test::Test____this__Test() {
    
    //#line 6 "/Users/ishii/workspace/rpx10/Test.x10": x10.ast.X10Return_c
    return ((Test*)this);
    
}

//#line 6 "/Users/ishii/workspace/rpx10/Test.x10": x10.ast.X10ConstructorDecl_c
void Test::_constructor() {
    
    //#line 6 "/Users/ishii/workspace/rpx10/Test.x10": x10.ast.AssignPropertyCall_c
    
}
Test* Test::_make() {
    Test* this_ = new (memset(x10aux::alloc<Test>(), 0, sizeof(Test))) Test();
    this_->_constructor();
    return this_;
}


const x10aux::serialization_id_t Test::_serialization_id = 
    x10aux::DeserializationDispatcher::addDeserializer(Test::_deserializer, x10aux::CLOSURE_KIND_NOT_ASYNC);

void Test::_serialize_body(x10aux::serialization_buffer& buf) {
    
}

x10::lang::Reference* Test::_deserializer(x10aux::deserialization_buffer& buf) {
    Test* this_ = new (memset(x10aux::alloc<Test>(), 0, sizeof(Test))) Test();
    buf.record_reference(this_);
    this_->_deserialize_body(buf);
    return this_;
}

void Test::_deserialize_body(x10aux::deserialization_buffer& buf) {
    
}

x10aux::RuntimeType Test::rtt;
void Test::_initRTT() {
    if (rtt.initStageOne(&rtt)) return;
    const x10aux::RuntimeType** parents = NULL; 
    rtt.initStageTwo("Test",x10aux::RuntimeType::class_kind, 0, parents, 0, NULL, NULL);
}

/* END of Test */
/*************************************************/
