*** Settings ***
Library                         QForce
Library                         FakerLibrary
Library                         Collections
Library                         String

*** Keywords ***
    # Login to Salesforce
    #                           Open Browser                ${url}                      chrome
    #                           TypeText                    Username                    ${username}
    #                           TypeSecret                  Password                    ${password}
    #                           ClickText                   Log In to Sandbox

Setup Browser
    [Arguments]                 ${url}=about:blank          ${browser}=chrome
    Set Library Search Order    QWeb                        QForce
    Open Browser                ${url}                      ${browser}
    SetConfig                   LineBreak                   ${EMPTY}                    #\ue000
    SetConfig                   DefaultTimeout              30s                         #sometimes salesforce is slow
    Evaluate                    random.seed()               random                      # initialize random generator
    SetConfig                   Delay                       0.3                         # adds a delay of 0.3 between keywords. This is helpful in cloud with limited resources.

Determine Login Strategy
    [Arguments]                 ${provided_username}=${None}                            ${provided_password}=${None}                          ${browser}=chrome
    ${DYNAMIC_LOGIN}=           Get Variable Value          ${loginUrl}                 NoValuePassed
    Log                         ${DYNAMIC_LOGIN}            console=true

    IF                          '${DYNAMIC_LOGIN}' == 'NoValuePassed'
        Set Global Variable     ${loginUrl}                 ${url}                      # CRT local
    END

    # CI/CD sysadmin: This condition is met if ${loginUrl} is provided but neither ${username} nor ${password} is provided. This suggests a scenario where a login URL is enough for access, typically for admin or generic system access without specific user credentials. Once executed, tests can use login as.
    # User Login provided by test: This condition is met if ${loginUrl}, ${username}, and ${password} are all provided. This indicates that specific user credentials are required for login, which is typical for user-specific authentication processes.
    # Default User CRT local: This is the default or fallback condition if neither of the above conditions is met. It covers scenarios where either the ${loginUrl} is not provided or one of the ${username} or ${password} is missing, suggesting a local or development environment where the login might be handled differently or with different credentials.
    # ${loginStrategy}=         Evaluate                    'CI/CD sysadmin' if ${loginUrl} and 'frontdoor' in ${loginUrl} else ('User Login' if '${loginUrl}' and '${provided_username}' and '${provided_password}' else 'CRT local')
    ${loginStrategy}=           Evaluate                    'CI/CD sysadmin' if '${loginUrl}' and 'frontdoor' in '${loginUrl}' and '${provided_username}' == 'None' and '${provided_password}' == 'None' else ('User Login' if '${loginUrl}' and '${provided_username}' != 'None' and '${provided_password}' != 'None' else 'CRT local')
    Log                         Selected login strategy: ${loginStrategy}               console=true

    Run Keyword If              '${loginStrategy}' == 'CI/CD sysadmin'                  CI/CD Sysadmin Login        ${loginUrl}               ${browser}
    Run Keyword If              '${loginStrategy}' == 'User Login'                      User Login                  ${loginUrl}               ${provided_username}      ${provided_password}    ${browser}
    Run Keyword If              '${loginStrategy}' == 'CRT local'                       CRT Local Login             ${loginUrl}               ${username}               ${password}               ${browser}

CI/CD Sysadmin Login
    [Arguments]                 ${loginUrl}                 ${browser}
    Log                         Logging in as CI/CD sysadmin...

    Setup Browser               ${loginUrl}                 ${browser}
    ${url}=                     Get Base URL                ${loginUrl}
    Set Global Variable         ${url}                      ${url}

User Login
    [Arguments]                 ${loginUrl}                 ${username}                 ${password}                 ${browser}                ${mfa_secret}=${EMPTY}
    Set Library Search Order    QForce                      QWeb
    Log                         Logging in as user...

    ${base_url}=                Get Base URL                ${loginUrl}
    Setup Browser               ${base_url}                 ${browser}
    TypeText                    Username                    ${username}
    TypeSecret                  Password                    ${password}
    ClickText                   Log In

    IF                          "${mfa_secret}" != "${EMPTY}"
        ${mfa_code}=            GetOTP                      ${username}                 ${mfa_secret}
        TypeSecret              Verification Code           ${mfa_code}
        ClickText               Verify
    END

CRT Local Login
    [Arguments]                 ${loginUrl}    ${username}                 ${password}                 ${browser}                  ${mfa_secret}=${EMPTY}
    Set Library Search Order    QForce                      QWeb
    Log                         Logging in locally for CRT...


    # Assuming ${url} is configured on robot variables.
    Setup Browser               ${loginUrl}                 ${browser}
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
    # ${loginUrl} passed by CI/CD contains by default an authenticated token: https://xxxxx.sandbox.xxx.xxxxx.com/more/more/token?=xa123123dsadasd
    # As we don't want to use the token to login, we need to retrieve the base url to enter the login screen.
    ${parts}=                   Split String                ${loginUrl}                 /
    ${base_url}=                Set Variable                ${parts[0]}//${parts[2]}
    [Return]                    ${base_url}


# Login as HC PAC user
#     Set Library Search Order    QForce                      QWeb
#     ClickText                   Setup                       delay=4s
#     ClickText                   Setup for current app
#     SwitchWindow                NEW
#     ${base_url}=                Get Base URL                ${loginUrl}
#     Go To                       ${base_url}/lightning/setup/EnhancedProfiles/home
#     VerifyText                  Profile Name
#     Click Text                  H                           anchor=Other
#     ClickText                   HC PAC User                 partial_match=false
#     ClickText                   Assigned Users
#     UseTable                    Profile
#     ClickCell                   r?Login/c3
#     ClickText                   Login                       Anchor=Reset Password
#     SwitchWindow                NEW
#     VerifyText                  Logged in as                timeout=120s
#     Sleep                       5s

# Login as System Administrator user
#     Set Library Search Order    QForce                      QWeb
#     ClickText                   Setup                       delay=4s
#     ClickText                   Setup for current app
#     SwitchWindow                NEW
#     ${base_url}=                Get Base URL                ${loginUrl}
#     Go To                       ${base_url}/lightning/setup/EnhancedProfiles/home
#     VerifyText                  Profile Name
#     Click Text                  S                           anchor=Other
#     ClickText                   System Administrator        partial_match=false
#     ClickText                   Assigned Users
#     UseTable                    Profile
#     ClickCell                   r?Login/c3
#     ClickText                   Login                       Anchor=Reset Password
#     SwitchWindow                NEW
#     VerifyText                  Logged in as                timeout=120s
#     Sleep                       5s
