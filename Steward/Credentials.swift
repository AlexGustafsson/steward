import Foundation
import Security

struct Credentials: Codable {
  var region: String
  var key: String
  var secret: String
  var bucket: String
}

enum KeychainError: Error {
  case itemNotFound
  case unexpectedStatus(OSStatus)
  case invalidData
}

func SetCredentials(_ credentials: Credentials) throws {
  let data = try JSONEncoder().encode(credentials)

  let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "blobstorage",
    kSecAttrService as String: "Steward",
    kSecValueData as String: data,
  ]

  let status = SecItemAdd(query as CFDictionary, nil)
  switch status {
  case errSecSuccess:
    return
  case errSecDuplicateItem:
      let update: [String: Any] = [
        kSecValueData as String: data
      ]
    let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
      switch status {
      case errSecSuccess:
        return
      default:
        throw KeychainError.unexpectedStatus(status)
      }
  default:
    throw KeychainError.unexpectedStatus(status)
  }
}

func CredentialsExist() throws -> Bool {
  let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "blobstorage",
    kSecAttrService as String: "Steward",
    kSecReturnData as String: false,
  ]

  let status = SecItemCopyMatching(query as CFDictionary, nil)
  switch status {
  case errSecSuccess:
    return true
  case errSecItemNotFound:
    return false
  default:
    throw KeychainError.unexpectedStatus(status)
  }
}

func GetCredentials() throws -> Credentials? {
  let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "blobstorage",
    kSecAttrService as String: "Steward",
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne,
  ]

  var result: AnyObject?

  let status = SecItemCopyMatching(query as CFDictionary, &result)
  switch status {
  case errSecSuccess:
    return try JSONDecoder().decode(Credentials.self, from: result as! Data)
  case errSecItemNotFound:
    return nil
  default:
    throw KeychainError.unexpectedStatus(status)
  }
}
