import Foundation

func relPath(_ path: String) -> URL {
    let resourcesURL = Bundle.module.resourceURL!
    return resourcesURL.appending(path: path)
}
