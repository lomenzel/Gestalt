#include "core.hpp"
#include <iostream>
#include <string>
#include <vector>
#include <limits>
#include <random>
#include <algorithm>
#include <cctype>

// Include libcurl!
#include <curl/curl.h>

using Value = GestaltCore::Value;

// --- Forward Declarations ---
void clearScreen();
void flushInput();
void executeEffect(GestaltCore& core, const Value& effect);
void invokeAction(GestaltCore& core, const std::string& actionName, const Value& params);

// --- UI Helpers ---
void clearScreen() {
    std::cout << "\x1B[2J\x1B[H";
}

void flushInput() {
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
}

void invokeAction(GestaltCore& core, const std::string& actionName, const Value& params) {
    try {
        Value effect = core.dispatch(actionName, params);
        executeEffect(core, effect);
    } catch (const std::exception& e) {
        std::cout << "\n[ERROR] Action '" << actionName << "' failed: " << e.what() << "\n";
        std::cout << "Press Enter to continue...";
        flushInput();
        std::cin.get();
    }
}

// --- cURL Callbacks ---
// Appends raw incoming HTTP body data to our std::string
static size_t curlWriteBodyCallback(void* contents, size_t size, size_t nmemb, std::string* userp) {
    size_t totalSize = size * nmemb;
    userp->append((char*)contents, totalSize);
    return totalSize;
}

// Parses raw incoming HTTP headers into a map
static size_t curlWriteHeaderCallback(char* buffer, size_t size, size_t nitems, std::map<std::string, std::string>* headers) {
    size_t totalSize = size * nitems;
    std::string header(buffer, totalSize);
    size_t colonPos = header.find(':');
    
    if (colonPos != std::string::npos) {
        std::string key = header.substr(0, colonPos);
        std::string value = header.substr(colonPos + 1);
        
        // Trim whitespace from value
        size_t start = value.find_first_not_of(" \r\n\t");
        size_t end = value.find_last_not_of(" \r\n\t");
        if (start != std::string::npos && end != std::string::npos) {
            value = value.substr(start, end - start + 1);
        } else {
            value = "";
        }
        
        // Lowercase the key to match standard JS behavior (e.g. "Content-Type" -> "content-type")
        std::transform(key.begin(), key.end(), key.begin(), [](unsigned char c){ return std::tolower(c); });
        
        (*headers)[key] = value;
    }
    return totalSize;
}

// --- Effect Router ---
void executeEffect(GestaltCore& core, const Value& effect) {
    if (effect.type != Value::Type::Set) return;

    std::string effectId;
    try { effectId = effect["id"].asString(); } catch (...) { return; }

    if (effectId == "noop") {
        return;
    } 
    else if (effectId == "log") {
        try {
            std::cout << "LOG EFFECT: " << effect["params"]["message"].asString() << "\n";
            std::cout << "Press Enter to continue...";
            flushInput();
            std::cin.get();
        } catch (...) {}
    } 
    else if (effectId == "random") {
        try {
            Value params = effect["params"];
            long long min = params["from"].asInt();
            long long max = params["to"].asInt();

            std::random_device rd;
            std::mt19937 gen(rd());
            std::uniform_int_distribution<long long> dis(min, max);
            long long result = dis(gen);

            std::string cbAction = params["callbackActionId"].asString();
            Value::Set cbParams;
            cbParams["result"] = Value::fromInt(result);
            
            invokeAction(core, cbAction, Value::fromSet(cbParams));
        } catch (...) {
            std::cout << "[ERROR] Random effect missing parameters.\n";
        }
    } 
    else if (effectId == "invokeAction") {
        try {
            Value params = effect["params"];
            std::string actionId = params["actionId"].asString();
            Value innerParams = Value::fromSet(Value::Set{});
            try { innerParams = params["params"]; } catch (...) {}
            invokeAction(core, actionId, innerParams);
        } catch (...) {
            std::cout << "[ERROR] invokeAction effect missing parameters.\n";
        }
    } 
    else if (effectId == "httpRequest") {
        try {
            Value params = effect["params"];
            std::string url = params["url"].asString();
            std::string cbAction = params["callBackActionId"].asString();
            std::string method = "GET";
            try { method = params["method"].asString(); } catch (...) {}
            
            // Standardize method string
            std::transform(method.begin(), method.end(), method.begin(), [](unsigned char c){ return std::toupper(c); });

            if (method == "GET") {
                std::cout << "\n[HTTP EFFECT] Fetching: " << url << "...\n";

                CURL* curl = curl_easy_init();
                if (curl) {
                    std::string responseBody;
                    std::map<std::string, std::string> responseHeaders;

                    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
                    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L); // Follow redirects
                    
                    // Setup Body Callback
                    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curlWriteBodyCallback);
                    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &responseBody);

                    // Setup Header Callback
                    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, curlWriteHeaderCallback);
                    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &responseHeaders);

                    // Execute
                    CURLcode res = curl_easy_perform(curl);
                    
                    long httpStatus = 0;
                    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &httpStatus);
                    curl_easy_cleanup(curl);

                    if (res != CURLE_OK) {
                        std::cout << "  -> Request failed: " << curl_easy_strerror(res) << "\n";
                        httpStatus = 500; // Internal fallback for network failure
                    } else {
                        std::cout << "  -> Success! (Status: " << httpStatus << ")\n";
                    }

                    // Translate to Gestalt types
                    Value::Set cbParams;
                    cbParams["status"] = Value::fromInt(httpStatus);
                    cbParams["body"] = Value::fromString(responseBody);
                    
                    Value::Set gestaltHeaders;
                    for (const auto& kv : responseHeaders) {
                        gestaltHeaders[kv.first] = Value::fromString(kv.second);
                    }
                    cbParams["headers"] = Value::fromSet(std::move(gestaltHeaders));

                    // Dispatch Callback
                    invokeAction(core, cbAction, Value::fromSet(cbParams));
                } else {
                    std::cout << "[ERROR] Failed to initialize cURL.\n";
                }
            } else {
                std::cout << "[ERROR] Only GET requests are implemented in this C++ example.\n";
            }
        } catch (...) {
            std::cout << "[ERROR] httpRequest effect missing parameters.\n";
        }
    } 
    else {
        std::cout << "\n[UNKNOWN EFFECT]: " << effectId << "\n";
        std::cout << "Press Enter to continue...";
        flushInput();
        std::cin.get();
    }
}

// --- Main ---
int main() {
    // Initialize cURL globally once per app lifetime
    curl_global_init(CURL_GLOBAL_DEFAULT);
    
    GestaltCore core;

    while (true) {
        clearScreen();

        std::cout << "========================================\n";
        try {
            std::cout << "  " << core.getMeta()["title"].asString() 
                      << " v" << core.getMeta()["version"].asString() << "\n";
        } catch (...) {
            std::cout << "  Gestalt Application\n";
        }
        std::cout << "========================================\n\n";

        Value view = core.viewState();
        if (view.type != Value::Type::Set) break;

        // Render UI Elements
        try {
            Value elements = view["elements"];
            if (elements.type == Value::Type::List) {
                for (const auto& el : std::get<Value::List>(elements.value)) {
                    if (el.type == Value::Type::Set) std::cout << "  " << el["content"].asString() << "\n";
                }
            }
        } catch (...) {}
        std::cout << "\n----------------------------------------\n\n";

        // Render Actions Menu
        std::vector<std::string> actionIds;
        try {
            Value actions = view["actions"];
            if (actions.type == Value::Type::List) {
                int index = 1;
                for (const auto& act : std::get<Value::List>(actions.value)) {
                    if (act.type == Value::Type::Set) {
                        std::string label = "";
                        try { label = act["content"].asString(); } catch(...) { label = act["actionId"].asString(); }
                        std::cout << "  [" << index << "] " << label << "\n";
                        actionIds.push_back(act["actionId"].asString());
                        index++;
                    }
                }
            }
        } catch (...) {}
        std::cout << "  [0] Exit Application\n\n";

        std::cout << "Select an action > ";
        int choice;
        if (!(std::cin >> choice)) {
            flushInput();
            continue;
        }

        if (choice == 0) {
            std::cout << "Goodbye!\n";
            break;
        }

        if (choice > 0 && choice <= (int)actionIds.size()) {
            std::string selectedAction = actionIds[choice - 1];
            Value::Set paramMap;

            try {
                Value expectedParams = core.getActionParams()[selectedAction];
                if (expectedParams.type == Value::Type::List) {
                    for (const auto& pNameVal : std::get<Value::List>(expectedParams.value)) {
                        std::string pName = pNameVal.asString();
                        std::cout << "  Enter value for '" << pName << "': ";
                        std::string inputStr;
                        std::cin >> inputStr;

                        try {
                            long long val = std::stoll(inputStr);
                            paramMap[pName] = Value::fromInt(val);
                        } catch (...) {
                            paramMap[pName] = Value::fromString(inputStr);
                        }
                    }
                }
            } catch (...) {}

            invokeAction(core, selectedAction, Value::fromSet(paramMap));
        }
    }

    // Cleanup cURL
    curl_global_cleanup();
    return 0;
}