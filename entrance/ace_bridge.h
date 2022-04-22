
void CallOCMethod(void *obj);
int64_t CallOC_CreateResource(void *obj, const std::string& resourceType, const std::string& param);
bool CallOC_OnMethodCall(void *obj, const std::string& method, const std::string& param, std::string& result);
bool CallOC_ReleaseResource(void *obj, const std::string& resourceHash);