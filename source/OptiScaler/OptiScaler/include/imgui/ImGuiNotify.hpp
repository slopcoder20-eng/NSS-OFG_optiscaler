   
                        
                                                                            
   
                                      
                                             
   
                               
                   
   

#ifndef IMGUI_NOTIFY
#define IMGUI_NOTIFY

#pragma once

#include <vector>			                                        
#include <string>
#include <chrono>			                                       
#include <functional>		                                                                                

#include "imgui.h"
#include "imgui_internal.h"








   
                              
  

#define NOTIFY_MAX_MSG_LENGTH				4096		                             
#define NOTIFY_PADDING_X					20.f		                        
#define NOTIFY_PADDING_Y					20.f		                        
#define NOTIFY_PADDING_MESSAGE_Y			10.f		                                 
#define NOTIFY_FADE_IN_OUT_TIME				150			                           
#define NOTIFY_DEFAULT_DISMISS				3000		                                                                                      
#define NOTIFY_OPACITY						0.8f		                    
#define NOTIFY_USE_SEPARATOR 				false 		                                                                          
#define NOTIFY_USE_DISMISS_BUTTON			false		                                                                                  
#define NOTIFY_RENDER_LIMIT					5			                                                                         

                                                              
#ifndef NOTIFY_RENDER_OUTSIDE_MAIN_WINDOW
#define NOTIFY_RENDER_OUTSIDE_MAIN_WINDOW	false		                                                                                                                       
#endif

   
                            
  








static const ImGuiWindowFlags NOTIFY_DEFAULT_TOAST_FLAGS = ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoNav | ImGuiWindowFlags_NoBringToFrontOnFocus | ImGuiWindowFlags_NoFocusOnAppearing;

#define NOTIFY_NULL_OR_EMPTY(str)		(!str || !strlen(str))
#define NOTIFY_FORMAT(fn, format, ...)	if (format) {va_list args; va_start(args, format); fn(format, args, ##__VA_ARGS__); va_end(args);}

enum class ImGuiToastType : uint8_t
{
    None,
    Success,
    Warning,
    Error,
    Info,
    COUNT
};

enum class ImGuiToastPhase : uint8_t
{
    FadeIn,
    Wait,
    FadeOut,
    Expired,
    COUNT
};

enum class ImGuiToastPos : uint8_t
{
    TopLeft,
    TopCenter,
    TopRight,
    BottomLeft,
    BottomCenter,
    BottomRight,
    Center,
    COUNT
};

   
                                                              
   
class ImGuiToast
{
private:
    ImGuiWindowFlags							flags = NOTIFY_DEFAULT_TOAST_FLAGS;

    ImGuiToastType								type = ImGuiToastType::None;
    char										title[NOTIFY_MAX_MSG_LENGTH];
    char										content[NOTIFY_MAX_MSG_LENGTH];

    int											dismissTime = NOTIFY_DEFAULT_DISMISS;
    std::chrono::system_clock::time_point		creationTime = std::chrono::system_clock::now();

    std::function<void()>						onButtonPress = nullptr;                                                                                    
    char 										buttonLabel[NOTIFY_MAX_MSG_LENGTH];
    int id = 0;                                               

private:
              

    inline void setTitle(const char* format, va_list args)
    {
        vsnprintf(this->title, sizeof(this->title), format, args);
    }

    inline void setContent(const char* format, va_list args)
    {
        vsnprintf(this->content, sizeof(this->content), format, args);
    }

    inline void setButtonLabel(const char* format, va_list args)
    {
        vsnprintf(this->buttonLabel, sizeof(this->buttonLabel), format, args);
    }

    inline ImVec4 toneMapColor(const ImVec4& color)
    {
                                                           
        float luminance = 0.2126f * color.x + 0.7152f * color.y + 0.0722f * color.z;
        float mappedLuminance = luminance / (1.0f + luminance);
        float scale = mappedLuminance / luminance;

        return ImVec4(color.x * scale, color.y * scale, color.z * scale, color.w);
    }

public:
    public:
    inline int getId() const { return this->id; }

       
                                                      
       
                                                     
                                                      
       
    inline void setTitle(const char* format, ...)
    {
        NOTIFY_FORMAT(this->setTitle, format);
    }

       
                                                        
       
                                                       
                                                      
       
    inline void setContent(const char* format, ...)
    {
        NOTIFY_FORMAT(this->setContent, format);
    }

       
                                                     
       
                                                      
       
    inline void setType(const ImGuiToastType& type)
    {
        IM_ASSERT(type < ImGuiToastType::COUNT);
        this->type = type;
    };

       
                                                              
       
                                              
      
    inline void setWindowFlags(const ImGuiWindowFlags& flags)
    {
        this->flags = flags;
    }

       
                                                                              
       
                                                                                                     
      
    inline void setOnButtonPress(const std::function<void()>& onButtonPress)
    {
        this->onButtonPress = onButtonPress;
    }

       
                                                               
       
                                                     
                                                      
      
    inline void setButtonLabel(const char* format, ...)
    {
        NOTIFY_FORMAT(this->setButtonLabel, format);
    }

public:
              

       
                                                      
       
                                                               
       
    inline const char* getTitle()
    {
        return this->title;
    };

       
                                                                                
       
                                                                       
       
    inline const char* getDefaultTitle()
    {
        if (!strlen(this->title))
        {
            switch (this->type)
            {
            case ImGuiToastType::None:
                return nullptr;
            case ImGuiToastType::Success:
                return "Success";
            case ImGuiToastType::Warning:
                return "Warning";
            case ImGuiToastType::Error:
                return "Error";
            case ImGuiToastType::Info:
                return "Info";
            default:
                return nullptr;
            }
        }

        return this->title;
    };

       
                                                     
       
                                                                 
       
    inline ImGuiToastType getType()
    {
        return this->type;
    };

       
                                                                        
       
                                                          
       
    inline ImVec4 getColor(bool toneMap = false)
    {
        ImVec4 color;

        switch (this->type)
        {
        case ImGuiToastType::None:
            color = { 255, 255, 255, 255 };         
            break;
        case ImGuiToastType::Success:
            color = {0, 255, 0, 255};         
            break;
        case ImGuiToastType::Warning:
            color = {255, 255, 0, 255};          
            break;
        case ImGuiToastType::Error:
            color = {255, 0, 0, 255};         
            break;
        case ImGuiToastType::Info:
            color = {0, 157, 255, 255};        
            break;
        default:
            color = {255, 255, 255, 255};         
        }

        if (toneMap)
            color = toneMapColor(color);

        return color;
    }

       
                                                                       
       
                                                              
       
    inline const char* getIcon() 
    { 
        return nullptr;
    }

       
                                                        
       
                                                           
       
    inline char* getContent() 
    {
        return this->content;
    };

       
                                                                                    
       
                                                        
                                                                                                     
       
    inline std::chrono::nanoseconds getElapsedTime() 
    {
        return std::chrono::system_clock::now() - this->creationTime;
    }

       
                                                                                                           
       
                                                                           
                                                                        
                                                                                    
                                                                          
                                                                                              
       
    inline ImGuiToastPhase getPhase()
    {
        const int64_t elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(getElapsedTime()).count();

        if (elapsed > NOTIFY_FADE_IN_OUT_TIME + this->dismissTime + NOTIFY_FADE_IN_OUT_TIME)
        {
            return ImGuiToastPhase::Expired;
        } else 
        if (elapsed > NOTIFY_FADE_IN_OUT_TIME + this->dismissTime)
        {
            return ImGuiToastPhase::FadeOut;
        } else 
        if (elapsed > NOTIFY_FADE_IN_OUT_TIME)
        {
            return ImGuiToastPhase::Wait;
        } else
        {
            return ImGuiToastPhase::FadeIn;
        }
    }

       
                                                           
                                                           
       
    inline float getFadePercent()
    {
         const ImGuiToastPhase phase = getPhase();
        const int64_t elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(getElapsedTime()).count();

        if (phase == ImGuiToastPhase::FadeIn)
        {
            return ((float)elapsed / (float)NOTIFY_FADE_IN_OUT_TIME) * NOTIFY_OPACITY;
        } else 
        if (phase == ImGuiToastPhase::FadeOut)
        {
            return (1.f - (((float)elapsed - (float)NOTIFY_FADE_IN_OUT_TIME - (float)this->dismissTime) / (float)NOTIFY_FADE_IN_OUT_TIME)) * NOTIFY_OPACITY;
        }

        return 1.f * NOTIFY_OPACITY;
    }

       
                                                       
      
    inline ImGuiWindowFlags getWindowFlags()
    {
        return this->flags;
    }

       
                                                                                       
      
    inline std::function<void()> getOnButtonPress()
    {
        return this->onButtonPress;
    }

       
                                                       
      
    inline const char* getButtonLabel()
    {
        return this->buttonLabel;
    }

public:
                   

       
                                                                                       
       
                                         
                                                                                                                                
       
    ImGuiToast(ImGuiToastType type, int dismissTime = NOTIFY_DEFAULT_DISMISS)
    {
        IM_ASSERT(type < ImGuiToastType::COUNT);

        this->type = type;
        this->dismissTime = dismissTime;

        this->creationTime = std::chrono::system_clock::now();

        static int toastIdCounter = 0;
        this->id = toastIdCounter++;

        memset(this->title, 0, sizeof(this->title));
        memset(this->content, 0, sizeof(this->content));
    }

       
                                                                                                     
       
                                                 
                                                       
                                                                                        
       
    ImGuiToast(ImGuiToastType type, const char* format, ...) : ImGuiToast(type)
    {
        NOTIFY_FORMAT(this->setContent, format);
    }

       
                                                                                                                       
       
                                                 
                                                                                         
                                                                            
                                                                                        
       
    ImGuiToast(ImGuiToastType type, int dismissTime, const char* format, ...) : ImGuiToast(type, dismissTime)
    {
        NOTIFY_FORMAT(this->setContent, format);
    }

       
                                                                                                                                              
       
                                                 
                                                                                         
                                                   
                                                                                          
                                                                            
                                                                                        
       
    ImGuiToast(ImGuiToastType type, int dismissTime, const char* buttonLabel, const std::function<void()>& onButtonPress, const char* format, ...) : ImGuiToast(type, dismissTime)
    {
        NOTIFY_FORMAT(this->setContent, format);

        this->onButtonPress = onButtonPress;
        this->setButtonLabel(buttonLabel);
    }
};

namespace ImGui
{
    inline std::vector<ImGuiToast> notifications;

       
                                                              
                                                    
       
    inline void InsertNotification(const ImGuiToast& toast)
    {
        notifications.push_back(toast);
    }

       
                                                                    
       
                                                            
       
    inline void RemoveNotification(size_t index)
    {
        notifications.erase(notifications.begin() + index);
    }

       
                                                             
                                                                                                  
                                                                   
       
    inline void RenderNotifications(ImGuiToastPos toastPos, float scale, bool toneMap = false)
    {
        const ImVec2 mainWindowPos = GetMainViewport()->Pos;
        const ImVec2 mainWindowSize = GetMainViewport()->Size;

        float stackHeight = 0.f;

        bool stylePushed = false;

        const static auto defaultStyle = ImGuiStyle();

        if (!notifications.empty())
        {
            ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, defaultStyle.WindowPadding * scale);
            ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, defaultStyle.FramePadding * scale);
            ImGui::PushStyleVar(ImGuiStyleVar_CellPadding, defaultStyle.CellPadding * scale);
            ImGui::PushStyleVar(ImGuiStyleVar_SeparatorTextPadding, defaultStyle.SeparatorTextPadding * scale);

            ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, defaultStyle.ItemSpacing * scale);
            ImGui::PushStyleVar(ImGuiStyleVar_ItemInnerSpacing, defaultStyle.ItemInnerSpacing * scale);
            ImGui::PushStyleVar(ImGuiStyleVar_IndentSpacing, defaultStyle.IndentSpacing * scale);

            stylePushed = true;
        }

        for (size_t i = 0; i < notifications.size(); ++i)
        {
            ImGuiToast* currentToast = &notifications[i];

                                      
            if (currentToast->getPhase() == ImGuiToastPhase::Expired)
            {
                RemoveNotification(i);
                continue;
            }

            #if NOTIFY_RENDER_LIMIT > 0
                if (i > NOTIFY_RENDER_LIMIT)
                {
                    continue;
                }
            #endif

                                             
            const char* icon = currentToast->getIcon();
            const char* title = currentToast->getTitle();
            const char* content = currentToast->getContent();
            const char* defaultTitle = currentToast->getDefaultTitle();
            const float opacity = currentToast->getFadePercent();                                          

                               
            ImVec4 textColor = currentToast->getColor();
            textColor.w = opacity;

                                                      
            char windowName[50];
            #ifdef _WIN32
            sprintf_s(windowName, "##TOAST%d", currentToast->getId());
            #elif defined(__linux__) || defined(__EMSCRIPTEN__)
            std::sprintf(windowName, "##TOAST%d", currentToast->getId());
            #elif defined(__APPLE__)
            std::snprintf(windowName, 50, "##TOAST%d", currentToast->getId());
            #else
                throw "Unsupported platform";
            #endif

                                                       
            SetNextWindowBgAlpha(opacity);

            ImVec2 windowPos;
            ImVec2 pivot;

            switch (toastPos)
            {
            case ImGuiToastPos::TopLeft:
                windowPos =
                    ImVec2(mainWindowPos.x + NOTIFY_PADDING_X, mainWindowPos.y + NOTIFY_PADDING_Y + stackHeight);
                pivot = ImVec2(0.0f, 0.0f);
                break;
            case ImGuiToastPos::TopCenter:
                windowPos =
                    ImVec2(mainWindowPos.x + mainWindowSize.x * 0.5f, mainWindowPos.y + NOTIFY_PADDING_Y + stackHeight);
                pivot = ImVec2(0.5f, 0.0f);
                break;
            case ImGuiToastPos::TopRight:
                windowPos = ImVec2(mainWindowPos.x + mainWindowSize.x - NOTIFY_PADDING_X,
                                   mainWindowPos.y + NOTIFY_PADDING_Y + stackHeight);
                pivot = ImVec2(1.0f, 0.0f);
                break;
            case ImGuiToastPos::BottomLeft:
                windowPos = ImVec2(mainWindowPos.x + NOTIFY_PADDING_X,
                                   mainWindowPos.y + mainWindowSize.y - NOTIFY_PADDING_Y - stackHeight);
                pivot = ImVec2(0.0f, 1.0f);
                break;
            case ImGuiToastPos::BottomCenter:
                windowPos = ImVec2(mainWindowPos.x + mainWindowSize.x * 0.5f,
                                   mainWindowPos.y + mainWindowSize.y - NOTIFY_PADDING_Y - stackHeight);
                pivot = ImVec2(0.5f, 1.0f);
                break;
            case ImGuiToastPos::Center:
                windowPos = ImVec2(mainWindowPos.x + mainWindowSize.x * 0.5f,
                                   mainWindowPos.y + mainWindowSize.y * 0.5f + stackHeight);
                pivot = ImVec2(0.5f, 0.5f);
                break;
            case ImGuiToastPos::BottomRight:
            default:
                windowPos = ImVec2(mainWindowPos.x + mainWindowSize.x - NOTIFY_PADDING_X,
                                   mainWindowPos.y + mainWindowSize.y - NOTIFY_PADDING_Y - stackHeight);
                pivot = ImVec2(1.0f, 1.0f);
                break;
            }

            SetNextWindowPos(windowPos, ImGuiCond_Always, pivot);

                                            
            if (!NOTIFY_USE_DISMISS_BUTTON && currentToast->getOnButtonPress() == nullptr)
            {
                currentToast->setWindowFlags(NOTIFY_DEFAULT_TOAST_FLAGS | ImGuiWindowFlags_NoInputs);
            }

            Begin(windowName, nullptr, currentToast->getWindowFlags());

                                            
            BringWindowToDisplayFront(GetCurrentWindow());

                                               
            {
                PushTextWrapPos(mainWindowSize.x / 3.f);                                                                                             

                bool wasTitleRendered = false;

                                    
                if (!NOTIFY_NULL_OR_EMPTY(icon))
                {
                                                     
                    TextColored(textColor, "%s", icon);
                    wasTitleRendered = true;
                }

                                    
                if (!NOTIFY_NULL_OR_EMPTY(title))
                {
                                                                                    
                    if (!NOTIFY_NULL_OR_EMPTY(icon))
                        SameLine();

                                                             
                    TextColored(textColor, "%s", title);
                    wasTitleRendered = true;
                } else 
                if (!NOTIFY_NULL_OR_EMPTY(defaultTitle))
                {
                    if (!NOTIFY_NULL_OR_EMPTY(icon))
                        SameLine();

                    TextColored(
                        textColor, "%s",
                        defaultTitle);                                                                           
                    wasTitleRendered = true;
                }

                                                 
                if (NOTIFY_USE_DISMISS_BUTTON)
                {
                                                                                                  
                    if (wasTitleRendered || !NOTIFY_NULL_OR_EMPTY(content))
                    {
                        SameLine();
                    }

                                                                        
                                           
                    float scale = 0.8f;

                    if (CalcTextSize(content).x > GetContentRegionAvail().x)
                    {
                        scale = 0.8f;
                    }

                    SetCursorPosX(GetCursorPosX() + (GetWindowSize().x - GetCursorPosX()) * scale);

                                                                                   
                    if (Button("X"))
                    {
                        RemoveNotification(i);
                    }
                }

                                                                                                                                           
                if (wasTitleRendered && !NOTIFY_NULL_OR_EMPTY(content))
                {
                    SetCursorPosY(GetCursorPosY() + 5.f);                                       
                }

                                      
                if (!NOTIFY_NULL_OR_EMPTY(content))
                {
                    if (wasTitleRendered)
                    {
                        #if NOTIFY_USE_SEPARATOR
                            Separator();
                        #endif
                    }

                    Text("%s", content);                       
                }

                                     
                if (currentToast->getOnButtonPress() != nullptr)
                {
                                                                                       
                    if (Button(currentToast->getButtonLabel()))
                    {
                        currentToast->getOnButtonPress()();
                    }
                }

                PopTextWrapPos();
            }

                                          
            auto windowSize = ImGui::GetWindowSize();

                  
            End();

            stackHeight += windowSize.y + NOTIFY_PADDING_MESSAGE_Y;
        }

        if (stylePushed)
            ImGui::PopStyleVar(7);
    }
}

#endif
