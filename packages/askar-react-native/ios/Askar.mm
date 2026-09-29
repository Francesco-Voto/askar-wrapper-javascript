#import <React/RCTBridge+Private.h>
#import <jsi/jsi.h>
#import <React/RCTUtils.h>
#import <ReactCommon/RCTTurboModule.h>
#import <ReactCommon/RCTInteropTurboModule.h>
#import <ReactCommon/RCTTurboModuleWithJSIBindings.h>
#import <askar/turboModuleUtility.h>

#import "Askar.h"

using namespace facebook;

@interface Askar () <RCTTurboModule, RCTTurboModuleWithJSIBindings>
@end

@implementation Askar 

RCT_EXPORT_MODULE()

// Expose this module as a TurboModule so React Native invokes
// installJSIBindingsWithRuntime:callInvoker: below when the module is created.
// This is the only supported way to install JSI bindings under the New
// Architecture / bridgeless mode, where [RCTBridge currentBridge] is nil and
// the legacy bridge is compiled out (RCT_REMOVE_LEGACY_ARCH=1).
//
// ObjCInteropTurboModule keeps the existing RCT_EXPORT methods (e.g. `install`)
// dispatchable without requiring a codegen spec, so this remains a drop-in
// change that also works on the old architecture.
- (std::shared_ptr<react::TurboModule>)getTurboModule:(const react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<react::ObjCInteropTurboModule>(params);
}

- (void)installJSIBindingsWithRuntime:(jsi::Runtime &)runtime
                          callInvoker:(const std::shared_ptr<react::CallInvoker> &)callInvoker
{
    askarTurboModuleUtility::registerTurboModule(runtime, callInvoker);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(install)
{
    // New Architecture: the JSI bindings are installed via
    // installJSIBindingsWithRuntime:callInvoker: when this TurboModule is
    // created, so there is nothing to do here.
    //
    // Old Architecture (legacy bridge present): install using the bridge
    // runtime so this keeps working for non-bridgeless apps.
    //
    // RCTCxxBridge (and its `runtime` accessor) was removed from public headers
    // in RN 0.87+ bridgeless-only builds. Rather than statically redeclaring the
    // selector via a category (which could clash with the real declaration still
    // present on older RN versions where the header IS importable), dispatch to
    // it dynamically with NSInvocation. This compiles identically regardless of
    // which RN version's headers are available, and safely no-ops when the
    // bridge doesn't implement `runtime` at all (bridgeless mode on 0.87+, where
    // [RCTBridge currentBridge] is nil anyway).
    RCTBridge* bridge = [RCTBridge currentBridge];
    SEL runtimeSelector = NSSelectorFromString(@"runtime");
    if (bridge != nil && [bridge respondsToSelector:runtimeSelector]) {
        NSMethodSignature *signature = [bridge methodSignatureForSelector:runtimeSelector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.selector = runtimeSelector;
        invocation.target = bridge;
        [invocation invoke];

        void *runtimePtr = NULL;
        [invocation getReturnValue:&runtimePtr];

        jsi::Runtime* jsiRuntime = (jsi::Runtime*) runtimePtr;
        if (jsiRuntime != nil) {
            askarTurboModuleUtility::registerTurboModule(*jsiRuntime, bridge.jsCallInvoker);
        }
    }
    return @true;
}

@end
