import Foundation
import Testing

@testable import Config

@Suite
struct RestClientServiceConfigTests {
    struct TestCase {
        var description: String
        var input: String
        var wantErr: Bool = false
        var env: [String: String] = [:]
    }

    static var allTests: [TestCase] {
        return [
            TestCase(
                description: "BadScheme",
                input: """
                    {
                        "name": "foo",
                        "url": "bad scheme://authority"
                    }
                    """,
                wantErr: true
            ),
            TestCase(
                description: "ValidUrl",
                input: """
                    {
                        "name": "foo",
                        "url": "http://localhost/some/path"
                    }
                    """
            ),
            TestCase(
                description: "Token",
                input: """
                    {
                        "name": "foo",
                        "url": "http://localhost",
                        "credentials": {
                            "bearer": {
                                "token": "secret"
                            }
                        }
                    }
                    """
            ),
            TestCase(
                description: "TokenWithScheme",
                input: """
                    {
                        "name": "foo",
                        "url": "http://localhost",
                        "credentials": {
                            "bearer": {
                                "scheme": "Acmecorp-Token",
                                "token": "secret"
                            }
                        }
                    }
                    """
            ),
            TestCase(
                description: "MissingTlsOptions",
                input: """
                    {
                        "name": "foo",
                        "url": "http://localhost",
                        "credentials": {
                            "client_tls": {}
                        }
                    }
                    """,
                wantErr: true
            ),
            TestCase(
                description: "IncompleteTlsOptions",
                input: """
                    {
                        "name": "foo",
                        "url": "http://localhost",
                        "credentials": {
                            "client_tls": {
                                "cert": "cert.pem"
                            }
                        }
                    }
                    """,
                wantErr: true
            ),
            TestCase(
                description: "MultipleCredentialsOptions",
                input: """
                    {
                        "name": "foo",
                        "url": "http://localhost",
                        "credentials": {
                            "s3_signing": {
                                "environment_credentials": {}
                            },
                            "bearer": {
                                "scheme": "Acmecorp-Token",
                                "token": "secret"
                            }
                        }
                    }
                    """,
                wantErr: true
            ),
            // Tests that were not ported over:

            // TestCase(
            // 	description: "EmptyS3Options",
            // ),
            // TestCase(
            // 	description: "ValidS3EnvCreds",
            // ),
            // TestCase(
            // 	description: "ValidApiGatewayEnvCreds",
            // ),
            // TestCase(
            // 	description: "ValidS3MetadataCredsWithRole",
            // ),
            // TestCase(
            // 	description: "ValidS3MetadataCreds",
            // ),
            // TestCase(
            // 	description: "MissingS3MetadataCredOptions",
            // ),
            // TestCase(
            // 	description: "MultipleS3CredOptions/metadata+environment",
            // ),
            // TestCase(
            // 	description: "MultipleS3CredOptions/metadata+profile+environment+webidentity",
            // ),
            // TestCase(
            // 	description: "MultipleCredentialsOptions",
            // ),
            // TestCase(
            // 	description: "S3WebIdentityMissingEnvVars",
            // ),
            // TestCase(
            // 	description: "S3WebIdentityCreds",
            // ),
            // TestCase(
            // 	description: "S3AssumeRoleMissingEnvVars",
            // ),
            // TestCase(
            // 	description: "S3AssumeRoleCredsMissingSigningPlugin",
            // ),
            // TestCase(
            // 	description: "S3AssumeRoleCreds",
            // ),

            // TestCase(
            // 	description: "Oauth2NoTokenUrl",
            // ),
            // TestCase(
            // 	description: "Oauth2MissingScopes",
            // ),
            // TestCase(
            // 	description: "Oauth2MissingClientId",
            // ),
            // TestCase(
            // 	description: "Oauth2MissingSecret",
            // ),
            // TestCase(
            // 	description: "Oauth2Creds",
            // ),
            // TestCase(
            // 	description: "Oauth2GetCredScopes",
            // ),
            // TestCase(
            // 	description: "Oauth2JwtBearerMissingSigningKey",
            // ),
            // TestCase(
            // 	description: "Oauth2JwtBearerSigningKeyWithoutCorrespondingKey",
            // ),
            // TestCase(
            // 	description: "Oauth2JwtBearerSigningKeyWithCorrespondingKey",
            // ),
            // TestCase(
            // 	description: "Oauth2JwtBearerSigningKeyPublicKeyReference",
            // ),
            // TestCase(
            // 	description: "Oauth2WrongGrantType",
            // ),
            // TestCase(
            // 	description: "Oauth2ClientCredentialsMissingCredentials",
            // ),
            // TestCase(
            // 	description: "Oauth2ClientCredentialsJwtNoAdditionalClaims",
            // ),
            // TestCase(
            // 	description: "Oauth2ClientCredentialsJwtThumbprint",
            // ),
            // TestCase(
            // 	description: "Oauth2ClientCredentialsTooManyCredentials",
            // ),
            // TestCase(
            // 	description: "Oauth2ClientCredentialsJWTAuthentication",
            // ),
            // TestCase(
            // 	description: "Oauth2ClientCredentialsJWTAuthentication_with_AWS_KMS",
            // ),
            // TestCase(
            // 	description: "Oauth2ClientCredentialsJWTAuthentication_with_AWS_KMS_missing_credentials",
            // ),
            // TestCase(
            // 	description: "Oauth2ClientCredentialsJWTAuthentication with Azure KeyVault",
            // ),
            // TestCase(
            // 	description: "Oauth2ClientCredentialsJWTAuthentication with Azure KeyVault and missing managed identity",
            // ),
            // TestCase(
            //  description: "Oauth2CredsClientAssertionPath",
            // ),
            // TestCase(
            //  description: "Oauth2CredsClientAssertion",
            // ),
            TestCase(
                description: "ValidGCPMetadataIDTokenOptions",
                input: """
                    {
                        "name": "foo",
                        "url": "https://localhost",
                        "credentials": {
                            "gcp_metadata": {
                                "audience": "https://localhost"
                            }
                        }
                    }
                    """
            ),
            TestCase(
                description: "ValidGCPMetadataAccessTokenOptions",
                input: """
                    {
                        "name": "foo",
                        "url": "https://localhost",
                        "credentials": {
                            "gcp_metadata": {
                                "scopes": ["storage.read_only"]
                            }
                        }
                    }
                    """
            ),
            TestCase(
                description: "EmptyGCPMetadataOptions",
                input: """
                    {
                        "name": "foo",
                        "url": "http://localhost",
                        "credentials": {
                            "gcp_metadata": {
                            }
                        }
                    }
                    """,
                wantErr: true
            ),
            TestCase(
                description: "EmptyGCPMetadataIDTokenAudienceOption",
                input: """
                    {
                        "name": "foo",
                        "url": "https://localhost",
                        "credentials": {
                            "gcp_metadata": {
                                "audience": ""
                            }
                        }
                    }
                    """,
                wantErr: true
            ),
            TestCase(
                description: "EmptyGCPMetadataAccessTokenScopesOption",
                input: """
                    {
                        "name": "foo",
                        "url": "https://localhost",
                        "credentials": {
                            "gcp_metadata": {
                                "scopes": []
                            }
                        }
                    }
                    """,
                wantErr: true
            ),
            TestCase(
                description: "InvalidGCPMetadataOptions",
                input: """
                    {
                        "name": "foo",
                        "url": "https://localhost",
                        "credentials": {
                            "gcp_metadata": {
                                "audience": "https://localhost",
                                "scopes": ["storage.read_only"]
                            }
                        }
                    }
                    """,
                wantErr: true
            ),
            TestCase(
                description: "Plugin",
                input: """
                    {
                        "name": "foo",
                        "url": "http://localhost",
                        "credentials": {
                            "plugin": "my_plugin"
                        }
                    }
                    """
            ),
            TestCase(
                description: "Unknown plugin",
                input: """
                    {
                        "name": "foo",
                        "url": "http://localhost",
                        "credentials": {
                            "plugin": "unknown_plugin"
                        }
                    }
                    """,
                wantErr: true
            ),
        ]
    }

    @Test(arguments: allTests)
    func testRoundtripSerdes(tc: TestCase) throws {
        let rawConfig = tc.input
        do {
            let parsedConfig = try JSONDecoder().decode(
                RestClientServiceConfig.self, from: rawConfig.data(using: .utf8)!)
            let encodedConfig = try JSONEncoder().encode(parsedConfig)

            let roundTrippedConfig = try JSONDecoder().decode(
                RestClientServiceConfig.self, from: encodedConfig)

            // Comapre the first config we parsed against the round-tripped one.
            #expect(parsedConfig == roundTrippedConfig)
        } catch {
            guard tc.wantErr else {
                throw error
            }
            return  // Error was expected. Continue.
        }
    }
}

extension RestClientServiceConfigTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
