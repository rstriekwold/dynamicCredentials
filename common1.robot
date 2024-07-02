*** Settings ***
Library                         QForce
Library                         FakerLibrary
Library                         Collections
# Library                       QVision
Library                         String
Resource                        ${CURDIR}${/}..${/}resources${/}PatientNew.resource
Variables                       ${CURDIR}${/}..${/}files${/}DefaultPatient.yaml


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

Close All Sales Console Tabs
    [Documentation]             Closes all tabs
    ClickUntilNoElements        xpath=//li[./a[@role\="tab" and not(contains(@data-tabid, "_"))]]//button[contains(@title, "Close")]

    # Close All Subtabs
    #                           [Documentation]             Closes all subtabs from Lightning Sales Console app
    #                           ...                         Subtabs mean the second row of tabs which might be present
    #                           VerifyText                  Lightning Sales Console
    #                           ClickUntilNoElements        xpath=//li[./a[@role\="tab" and (contains(@data-tabid, "_"))]]//button[contains(@title, "Close")]

Click Until No Elements
    [Documentation]             Clicks the element for given xpath until no such elements exist
    [Arguments]                 ${xpath}
    ${tabs_present}=            IsElement                   ${xpath}                    timeout=5
    WHILE                       ${tabs_present}             limit=5
        @{tabs_open}=           GetWebelement               locator=${xpath}
        FOR                     ${elem}                     IN                          @{tabs_open}
            RunKeywordAndIgnoreError                        ClickElement                ${elem}                     js=${TRUE}                timeout=2
        END
        Sleep                   1
        ${tabs_present}=        IsElement                   ${xpath}                    timeout=5
    END

    # Login to Salesforce
    #                           [Arguments]                 ${loginUrl}=${EMPTY}        ${browser}=chrome           ${username}=${username}                             ${password}=${password}    ${secret}=${EMPTY}
    #                           [Documentation]             This generic login keyword can be used to login from within test files. Mainly for test files to determine how to login for a specific test scenario.
    #                           ...                         - option1: CI/CD: login directly using loginUrl of the source/destination org using sysadmin credential. Ideal for deployment tasks and login as persona.
    #                           ...                         - option2: CI/CD: login using loginUrl of the source/destination org but using any orgUsername, orgPassword, mfa_secret (not using sysadmin credential)
    #                           ...                         - option3: CRT: login with local loginUrl, orgUsername and orgPassword for any user (using suite / robot variables)
    #                           Set Library Search Order    QForce                      QWeb
    #                           Log Variables
    #                           IF                          "${loginUrl}" == "${EMPTY}"
    #                           ${DYNAMIC_LOGIN}=           Set Variable                NoValuePassed
    #                           ELSE
    #                           ${DYNAMIC_LOGIN}=           Set Variable                ${loginUrl}
    #                           END
    #                           # ${DYNAMIC_LOGIN}=         Get Variable Value          ${loginUrl}                 NoValuePassed
    #                           IF                          '${DYNAMIC_LOGIN}' != 'NoValuePassed'
    #                           IF                          "${username}" == "${EMPTY}" and "${password}" == "${EMPTY}"
    #                           # option 1
    #                           Setup Browser               ${DYNAMIC_LOGIN}            ${browser}
    #                           # Add steps here to set env variable and load variables
    #                           ELSE
    #                           # option 2
    #                           ${parts}=                   Split String                ${DYNAMIC_LOGIN}            # e.g. ${DYNAMIC_LOGIN} = 'https://xxxxx.sandbox.xxx.xxxxx.com/more/more/token
    #                           ${base_url}=                Set Variable                ${parts[0]}//${parts[2]}    # e.g. ${parts} = ['https:', '', 'xxxxx.sandbox.xxx.xxxxx.com', 'more', 'more', '']
    #                           Setup Browser               ${base_url}                 ${browser}
    #                           TypeText                    Username                    ${username}
    #                           TypeSecret                  Password                    ${password}
    #                           ClickText                   Log In
    #                           # ${MFA_needed}=            Run Keyword And Return Status                           Should Not Be Equal       ${None}                   ${MFA_SECRET}
    #                           # IF                        ${MFA_needed}
    #                           #                           ${mfa_code}=                GetOTP                      ${ORG_USERNAME}           ${MFA_SECRET}
    #                           #                           TypeSecret                  Verification Code           ${mfa_code}
    #                           #                           ClickText                   Verify
    #                           # END
    #                           END
    #                           ELSE
    #                           # option3
    #                           Import Variables from Files
    #                           Setup Browser               ${url}                      ${BROWSER}
    #                           TypeText                    Username                    ${username}
    #                           TypeSecret                  Password                    ${password}
    #                           ClickText                   Log In
    #                           # ${MFA_needed}=            Run Keyword And Return Status                           Should Not Be Equal       ${None}                   ${MY_SECRET}
    #                           # IF                        ${MFA_needed}
    #                           #                           ${mfa_code}=                GetOTP                      ${username}               ${MY_SECRET}
    #                           #                           TypeSecret                  Verification Code           ${mfa_code}
    #                           #                           ClickText                   Verify
    #                           # END
    #                           END

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
    Close All Sales Console Tabs

CI/CD Sysadmin Login
    [Arguments]                 ${loginUrl}                 ${browser}
    Log                         Logging in as CI/CD sysadmin...
    Import Variables from Files
    Setup Browser               ${loginUrl}                 ${browser}
    ${url}=                     Get Base URL                ${loginUrl}
    Set Global Variable         ${url}                      ${url}

User Login
    [Arguments]                 ${loginUrl}                 ${username}                 ${password}                 ${browser}                ${mfa_secret}=${EMPTY}
    Set Library Search Order    QForce                      QWeb
    Log                         Logging in as user...

    Import Variables from Files

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

    Import Variables from Files

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

Import Variables from Files
    IF                          'trndev1' in '${loginUrl}'
        Set Suite Variable      ${env}                      DEV1
    END
    # Add other environments here too.
    Import Variables            ${CURDIR}${/}..${/}files${/}${env}-MRNs.yaml

Login as HC PAC user
    Set Library Search Order    QForce                      QWeb
    ClickText                   Setup                       delay=4s
    ClickText                   Setup for current app
    SwitchWindow                NEW
    ${base_url}=                Get Base URL                ${loginUrl}
    Go To                       ${base_url}/lightning/setup/EnhancedProfiles/home
    VerifyText                  Profile Name
    Click Text                  H                           anchor=Other
    ClickText                   HC PAC User                 partial_match=false
    ClickText                   Assigned Users
    UseTable                    Profile
    ClickCell                   r?Login/c3
    ClickText                   Login                       Anchor=Reset Password
    SwitchWindow                NEW
    VerifyText                  Logged in as                timeout=120s
    Sleep                       5s

Login as System Administrator user
    Set Library Search Order    QForce                      QWeb
    ClickText                   Setup                       delay=4s
    ClickText                   Setup for current app
    SwitchWindow                NEW
    ${base_url}=                Get Base URL                ${loginUrl}
    Go To                       ${base_url}/lightning/setup/EnhancedProfiles/home
    VerifyText                  Profile Name
    Click Text                  S                           anchor=Other
    ClickText                   System Administrator        partial_match=false
    ClickText                   Assigned Users
    UseTable                    Profile
    ClickCell                   r?Login/c3
    ClickText                   Login                       Anchor=Reset Password
    SwitchWindow                NEW
    VerifyText                  Logged in as                timeout=120s
    Sleep                       5s

Login as Sarah ONeill
    Set Library Search Order    QForce                      QWeb
    ClickText                   Setup                       delay=4s
    ClickText                   Setup for current app
    SwitchWindow                NEW
    ${base_url}=                Get Base URL                ${loginUrl}
    Go To                       ${base_url}/lightning/setup/ManageUsers/home
    VerifyText                  All Users
    Click Text                  O                           anchor=Other
    ClickText                   SOnei                       partial_match=false
    # UseTable                  Full Name
    # ClickCell                 r?Oneill, Sarah/c3
    ClickText                   Login                       Anchor=Reset Password
    SwitchWindow                NEW
    VerifyText                  Logged in as                timeout=120s
    Sleep                       5s

Logout as user
    Set Library Search Order    QForce                      QWeb
    ClickText                   Log out                     anchor=Sandbox:
    LaunchApp                   Patient Access Center Console

Open MRN
    Set Library Search Order    QForce                      QWeb
    Set Suite Variable          ${MRNno}                    ${epic_medical_records}[mrn_with_all_data][mrnno]
    ${checkMRNresult}=          Run Keyword And Return Status                           Open Account                ${MRNno}
    Log To Console              ${checkMRNresult}
    IF                          "${checkMRNresult}" == "False"
        LaunchApp               Patient Access Center Console
        ClickText               Show Navigation Menu
        ClickText               Patient Creation
        ${firstname}=           FakerLibrary.First Name
        ${lastname}=            FakerLibrary.Last Name
        ${fakessn}=             FakerLibrary.Ssn
        Set To Dictionary       ${PatientDict}              first_name=${firstname}     last_name=${lastname}       ssn=${fakessn}
        Enter New Patient       &{PatientDict}
        ClickText               Next
        ClickText               Generate MRN
        ${MRNno}=               GetFieldValue               Medical Record Number       timeout=60s
    END
