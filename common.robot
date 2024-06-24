*** Settings ***
Documentation                   Example resource file with custom keywords. NOTE: Some keywords below may need
...                             minor changes to work in different instances.
Library                         QForce
Library                         String


*** Variables ***
# IMPORTANT: Please read the readme.txt to understand needed variables and how to handle them!!
${BROWSER}                      chrome
${username}                     pace.delivery1@qentinel.com.demonew
${login_url}                    https://qentinel--demonew.my.salesforce.com/            # Salesforce instance. NOTE: Should be overwritten in CRT variables
${home_url}                     ${login_url}/lightning/page/home


*** Keywords ***
Setup Browserdwdsd
    # Setting search order is not really needed here, but given as an example
    # if you need to use multiple libraries containing keywords with duplicate names
    Set Library Search Order    QForce                      QWeb
    Open Browser                about:blank                 ${BROWSER}
    SetConfig                   LineBreak                   ${EMPTY}                    #\ue000
    Evaluate                    random.seed()               random                      # initialize random generator
    SetConfig                   DefaultTimeout              45s                         #sometimes salesforce is slow
    # adds a delay of 0.3 between keywords. This is helpful in cloud with limited resources.
    SetConfig                   Delay                       0.3

End suite
    Close All Browsers


Login
    [Documentation]             Login to Salesforce instance. Takes instance_url, username and password as
    ...                         arguments. Uses values given in Copado Robotic Testing's variables section by default.
    [Arguments]                 ${sf_instance_url}=${login_url}                         ${sf_username}=${username}                            ${sf_password}=${password}
    GoTo                        ${sf_instance_url}
    TypeText                    Username                    ${sf_username}              delay=1
    TypeSecret                  Password                    ${sf_password}
    ClickText                   Log In
    # We'll check if variable ${secret} is given. If yes, fill the MFA dialog.
    # If not, MFA is not expected.
    # ${secret} is ${None} unless specifically given.
    ${MFA_needed}=              Run Keyword And Return Status                           Should Not Be Equal         ${None}                   ${secret}
    Run Keyword If              ${MFA_needed}               Fill MFA                    ${sf_username}              ${secret}                 ${sf_instance_url}


Login As
    [Documentation]             Login As different persona. User needs to be logged into Salesforce with Admin rights
    ...                         before calling this keyword to change persona.
    ...                         Example:
    ...                         LoginAs                     Chatter Expert
    [Arguments]                 ${persona}
    ClickText                   Setup
    ClickItem                   Setup                       delay=1
    SwitchWindow                NEW
    TypeText                    Search Setup                ${persona}                  delay=2
    ClickElement                //*[@title\="${persona}"]                               delay=2                     # wait for list to populate, then click
    VerifyText                  Freeze                      timeout=45                  # this is slow, needs longer timeout
    ClickText                   Login                       anchor=Freeze               partial_match=False         delay=1


Fill MFA
    [Documentation]             Gets the MFA OTP code and fills the verification dialog (if needed)
    [Arguments]                 ${sf_username}=${username}                              ${mfa_secret}=${secret}     ${sf_instance_url}=${login_url}
    ${mfa_code}=                GetOTP                      ${sf_username}              ${mfa_secret}               ${login_url}
    TypeSecret                  Verification Code           ${mfa_code}
    ClickText                   Verify


Home
    [Documentation]             Example appstarte: Navigate to homepage, login if needed
    GoTo                        ${home_url}
    ${login_status} =           IsText                      To access this page, you have to log in to Salesforce.                            2
    Run Keyword If              ${login_status}             Login
    ClickText                   Home
    VerifyTitle                 Home | Salesforce


    # Example of custom keyword with robot fw syntax. NOTE: These keywords may need to be adjusted
    # to work in your environment
VerifyStage
    [Documentation]             Verifies that stage given in ${text} is at ${selected} state; either selected (true) or not selected (false)
    [Arguments]                 ${text}                     ${selected}=true
    VerifyElement               //a[@title\="${text}" and (@aria-checked\="${selected}" or @aria-selected\="${selected}")]


VerifyStageColor
    [Documentation]             Example keyword on how to verify background color of element.
    ...                         Note that this keyword might need adjusting in your instance (colors and locators can be different)
    [Arguments]                 ${stage_text}               ${color}=navy
    &{COLORS}=                  Create Dictionary           navy=rgba(1, 68, 134, 1)    green=rgba(59, 167, 85, 1)

    ${elem}=                    GetWebElement               ${stage_text}               element_type=item
    ${background_color}=        Evaluate                    $elem.value_of_css_property("background-color")
    Should Be Equal             ${COLORS.${color}}          ${background_color}         msg=Error: Background color ( ${background_color}) differs from ${color} (${COLORS.${color}})


NoData
    VerifyNoText                ${data}                     timeout=3                   delay=2


DeleteAccounts
    [Documentation]             RunBlock to remove all data until it doesn't exist anymore
    ClickText                   ${data}
    ClickText                   Delete
    VerifyText                  Are you sure you want to delete this account?
    ClickText                   Delete                      2
    VerifyText                  Undo
    VerifyNoText                Undo
    ClickText                   Accounts                    partial_match=False


DeleteLeads
    [Documentation]             RunBlock to remove all data until it doesn't exist anymore
    ClickText                   ${data}
    ClickText                   Delete
    VerifyText                  Are you sure you want to delete this lead?
    ClickText                   Delete                      2
    VerifyText                  Undo
    VerifyNoText                Undo
    ClickText                   Leads                       partial_match=False

CRT Local Login
    [Arguments]                 ${browser}=chrome           ${mfa_secret}=${EMPTY}
    Log                         Logging in locally using robot variables
    SetupBrowser                ${url}                      ${browser}
    TypeText                    Username                    ${username}
    TypeSecret                  Password                    ${password}
    ClickText                   Log In
    IF                          "${mfa_secret}"!="${EMPTY}"
        ${mfa_code}=            GetOTP                      ${username}                 ${mfa_secret}
        TypeSecret              VerificationCode            ${mfa_code}
        ClickText               Verify
    END

CI/CD Sysadmin Login            
    [Arguments]                 ${loginUrl}                 ${browser}=chrome
    Log                         Logging in as CI/CD sysadmi
    Setup Browser               ${loginUrl}                 ${browser}

User Login
    [Arguments]                 ${username}                 ${password}                 ${browser}                  ${mfa_secret}=${EMPTY}
    Log                         Loggingin as user…
    ${base_url}=                Get Base URL                ${loginUrl}
    Open Browser                ${base_url}                 ${browser}
    TypeText                    Username                    ${username}
    TypeSecret                  Password                    ${password}
    ClickText                   Log In
    IF                          "${mfa_secret}" != "${EMPTY}"
        ${mfa_code}=            GetOTP                      ${username}                 ${mfa_secret}
        TypeSecret              Verification Code           ${mfa_code}
        ClickText               Verify
    END


Get Base URL                   
    [Arguments]                 ${loginUrl}
    # Intercept the login url including token before login, navigate to the login screen instead
    ${parts}=                   Split String                ${loginUrl}                 /
    ${base_url}=                Set Variable                ${parts[0]}//${parts[2]}

Setup Browser
    [Arguments]                 ${url}=about:blank          ${browser}=chrome
    OpenBrowser                 ${url}                      ${browser}
    SetConfig                   LineBreak                   ${EMPTY}     #\ue000
    SetConfig                   DefaultTimeout              30s          #sometimesSalesforceisslow
    Evaluate                    random.seed()               random       #initializerandomgenerator
    SetConfig                   Delay                       0.3          #addsadelayof0.3betweenkeywords

Determine Login Strategy
    [Arguments]                 ${loginUrl}=${None}         ${provided_username}=${None}                            ${provided_password}=${None}                      ${browser}=chrome
    ${loginStrategy}=           Evaluate                    'CI/CD sysadmin' if '${loginUrl}' and 'frontdoor' in '${loginUrl}' and
    ...                         '${provided_username}' == 'None' and '${provided_password}' == 'None' else ('UserLogin' if '${loginUrl}'
    ...                         and '${provided_username}' != 'None' and '${provided_password}' != 'None' else 'CRTlocal')
    Log                         Selectedloginstrategy: ${loginStrategy}            console=true
    RunKeywordIf                '${loginStrategy}'=='CI/CD sysadmin'                    CI/CD Sysadmin Login        ${loginUrl}               ${browser}
    RunKeywordIf                '${loginStrategy}'=='UserLogin'                        User Login                  ${loginUrl}               ${provided_username}    ${provided_password}    ${browser}
    RunKeywordIf                '${loginStrategy}'=='CRTlocal'                         CRT Local Login             #${username}               ${password}             ${browser}


Login As Profile User
    [Arguments]                 ${profile}
    ClickText                   Setup                       delay=2s
    ClickText                   Setup for current app
    SwitchWindow                NEW
    GoTo                        ${url}/lightning/setup/EnhancedProfiles/home
    VerifyText                  Profile Name
    ${first_char}=              Get Substring                ${profile}                  0                           0
    ${char_ucase}=              Convert To Upper Case          ${first_char}
    ClickText                   ${char_ucase}               anchor=Other
    ClickText                   ${profile}                  partial_match=false         #e.g.SystemAdministrator
    ClickText                   Assigned Users
    UseTable                    Profile
    ClickCell                   r?Login/c3                  #Clicksloginonanyrow
    ClickText                   Login                       Anchor=Reset Password
    SwitchWindow                NEW
    VerifyText                  Logged in as                  timeout=45s

Logout As User
    ClickText                   Log out                      anchor=Sandbox:
