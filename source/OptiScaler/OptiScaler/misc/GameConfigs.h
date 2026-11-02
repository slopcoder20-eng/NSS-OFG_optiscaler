#pragma once

#include "Quirks.h"

#include <functional>
#include <string>
#include <vector>

struct GameConfigContext
{
    bool isNvidia = false;
};

                                                  
struct ConfigDefault
{
    std::string text;
    std::function<bool()> apply;                                                                 
    bool (*condition)(const GameConfigContext&) = nullptr;
};

struct GameConfig
{
    std::vector<std::string> exes;                         
    std::vector<std::string> ueExes;                                                                              
    std::vector<ConfigDefault> defaults;
    std::vector<GameQuirk> quirks;
};

                                                                                       
flag_set<GameQuirk> ApplyGameConfigs(std::string exeName, const GameConfigContext& context);
