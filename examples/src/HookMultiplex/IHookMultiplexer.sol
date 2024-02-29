type hookFlag is bool;

interface IHookMultiPlexer {
    struct ConfigParam {
        address hook;
        hookFlag isExecutorHook;
        hookFlag isValidatorHook;
        hookFlag isConfigHook;
    }
}
