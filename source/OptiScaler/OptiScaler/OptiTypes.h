#pragma once
#include <string>

   
                                                                      
   
namespace OptiKeys
{
using CString = const char[];

                                         
inline constexpr CString ProjectID = "OptiScaler";

                                             
inline constexpr CString VkProvider = "OptiVk";
                                           
inline constexpr CString Dx11Provider = "OptiDx11";
                                           
inline constexpr CString Dx12Provider = "OptiDx12";

inline constexpr CString FSR_UpscaleWidth = "FSR.upscaleSize.width";
inline constexpr CString FSR_UpscaleHeight = "FSR.upscaleSize.height";

inline constexpr CString FSR_NearPlane = "FSR.cameraNear";
inline constexpr CString FSR_FarPlane = "FSR.cameraFar";
inline constexpr CString FSR_CameraFovVertical = "FSR.cameraFovAngleVertical";
inline constexpr CString FSR_FrameTimeDelta = "FSR.frameTimeDelta";
inline constexpr CString FSR_ViewSpaceToMetersFactor = "FSR.viewSpaceToMetersFactor";
inline constexpr CString FSR_TransparencyAndComp = "FSR.transparencyAndComposition";
inline constexpr CString FSR_Reactive = "FSR.reactive";

}                      

template <typename T> struct EnumConfig;

typedef enum API
{
    NotSelected = 0,
    DX11,
    DX12,
    Vulkan,
} API;

enum class Upscaler
{

    XeSS,                                                     

    XeSS_on12,                                                                          

    FSR21,                                                           

    FSR21_on12,                                                                           

    FSR22,                                                           

    FSR22_on12,                                                                           

    FSR31,                                           

    FFX,                                                

    FFX_on12,                                                                         

    DLSS,                                              

    DLSS_on12,                            

    DLSSD,                                                                             

    NSS,                                                                    
    Reset
};

enum class ApiUpscalerInput
{
    DLSS_DX11,
    DLSS_DX12,
    DLSS_VK,
    XeSS_DX11,
    XeSS_DX12,
    XeSS_VK,
    FFX_DX12,
    FFX_VK,
    FSR20_DX12,
    FSR2X_DX11,
    FSR2X_DX12,
    FSR2X_VK,
    FSR2_TinyTina,
    FSR3_DX12,
};

enum class SharpenShader
{
    RCAS,
    DepthAware,
    LocalContrastDepthAware
};

template <> struct EnumConfig<SharpenShader>
{
    static constexpr auto default_value = SharpenShader::RCAS;

    static constexpr std::pair<SharpenShader, std::string_view> mapping[] = { { SharpenShader::RCAS, "rcas" },
                                                                              { SharpenShader::DepthAware, "da" },
                                                                              { SharpenShader::LocalContrastDepthAware,
                                                                                "lcda" } };
};

enum class FSR4Support : uint8_t
{
    None = 0,
    FP8 = 1,
    INT8 = 2,
    INT8_2 = 3,                      
    INT8Lite = 4,                                     
    Count
};

                                                                                     
enum class FSR4Model : uint8_t
{
    FP8 = 0,
    INT8 = 1,
    INT8_2 = 2,                      
    INT8Lite = 3,                                     
    Count
};

inline bool IsFsr4Int8(FSR4Support support)
{
    return support == FSR4Support::INT8 || support == FSR4Support::INT8_2 || support == FSR4Support::INT8Lite;
}

typedef struct _version_t
{
    uint16_t major;
    uint16_t minor;
    uint16_t patch;
    uint16_t reserved;

    _version_t() : major(0), minor(0), patch(0), reserved(0) {}

    constexpr _version_t(uint16_t maj, uint16_t min, uint16_t pat, uint16_t res)
        : major(maj), minor(min), patch(pat), reserved(res)
    {
    }

    bool operator==(const _version_t& other) const
    {
        return major == other.major && minor == other.minor && patch == other.patch && reserved == other.reserved;
    }

    bool operator!=(const _version_t& other) const { return !(*this == other); }

    bool operator<(const _version_t& other) const
    {
        if (major != other.major)
            return major < other.major;
        if (minor != other.minor)
            return minor < other.minor;
        if (patch != other.patch)
            return patch < other.patch;
        return reserved < other.reserved;
    }

    bool operator>(const _version_t& other) const { return other < *this; }

    bool operator<=(const _version_t& other) const { return !(other < *this); }

    bool operator>=(const _version_t& other) const { return !(*this < other); }
} version_t;

struct feature_version
{
    unsigned int major;
    unsigned int minor;
    unsigned int patch;
    unsigned int reserved;

    feature_version() : major(0), minor(0), patch(0), reserved(0) {}

    explicit feature_version(const char* version_str) : major(0), minor(0), patch(0), reserved(0)
    {
        parse_version(version_str);
    }

    constexpr feature_version(unsigned int maj, unsigned int min, unsigned int pat, unsigned int res)
        : major(maj), minor(min), patch(pat), reserved(res)
    {
    }

    constexpr feature_version(unsigned int maj, unsigned int min, unsigned int pat)
        : major(maj), minor(min), patch(pat), reserved(0)
    {
    }

    feature_version& operator=(const version_t& other)
    {
        this->major = other.major;
        this->minor = other.minor;
        this->patch = other.patch;
        this->reserved = other.reserved;
        return *this;
    }

    bool operator==(const feature_version& other) const
    {
        return major == other.major && minor == other.minor && patch == other.patch && reserved == other.reserved;
    }

    bool operator!=(const feature_version& other) const { return !(*this == other); }

    bool operator<(const feature_version& other) const
    {
        if (major != other.major)
            return major < other.major;
        if (minor != other.minor)
            return minor < other.minor;
        if (patch != other.patch)
            return patch < other.patch;
        return reserved < other.reserved;
    }

    bool operator>(const feature_version& other) const { return other < *this; }

    bool operator<=(const feature_version& other) const { return !(other < *this); }

    bool operator>=(const feature_version& other) const { return !(*this < other); }

    void parse_version(const char* version_str)
    {
        const char* p = version_str;

                                   
        while (*p)
        {
            if (isdigit((unsigned char) p[0]))
            {
                if (sscanf_s(p, "%u.%u.%u", &major, &minor, &patch) == 3)
                    return;
            }
            ++p;
        }

        LOG_WARN("can't parse {0}", version_str);
    }
};

namespace VendorId
{
enum Value : uint32_t
{
    Invalid = 0,
    Microsoft = 0x1414,                           
    Nvidia = 0x10DE,
    AMD = 0x1002,
    Intel = 0x8086,
};
};

std::string ApiUpscalerInputName(ApiUpscalerInput upscaler);

std::string UpscalerDisplayName(Upscaler upscaler, API api = API::NotSelected);
std::string UpscalerShortName(Upscaler upscaler);
bool IsFsr(Upscaler upscaler);

                                               
std::string UpscalerToCode(Upscaler upscaler);

                                             
Upscaler CodeToUpscaler(const std::string& code);

                                                       
                                                
Upscaler CodeToUpscalerFfx(const std::string& code);

                      
template <typename T> std::string EnumToCode(T value)
{
    for (const auto& pair : EnumConfig<T>::mapping)
    {
        if (pair.first == value)
            return std::string(pair.second);
    }
    return "";
}

constexpr char ToLower(char c) { return (c >= 'A' && c <= 'Z') ? static_cast<char>(c - 'A' + 'a') : c; }

                      
template <typename T> T CodeToEnum(std::string_view code)
{
    for (const auto& [value, mappedCode] : EnumConfig<T>::mapping)
    {
        if (std::ranges::equal(mappedCode, code, std::ranges::equal_to {}, ToLower, ToLower))
        {
            return value;
        }
    }

    return EnumConfig<T>::default_value;
}
