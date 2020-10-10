platform :ios, '13.4'
use_frameworks!

target 'Matrix Playground' do
    pod 'MatrixSDK'
    pod 'MatrixSDK/SwiftSupport'
    pod 'thenPromise'
    pod 'KeychainSwift', '~> 19.0'
    pod 'SwiftLocation', '~> 4.0'
end

target 'Matrix PlaygroundTests' do
    inherit! :search_paths
    pod 'Mockingjay', '3.0.0-alpha.1'
end

class Pod::Target::BuildSettings::AggregateTargetSettings
    alias_method :ld_runpath_search_paths_original, :ld_runpath_search_paths

    def ld_runpath_search_paths
        return ld_runpath_search_paths_original unless configuration_name == "Debug"
        return ld_runpath_search_paths_original + framework_search_paths
    end
end

class Pod::Target::BuildSettings::PodTargetSettings
    alias_method :ld_runpath_search_paths_original, :ld_runpath_search_paths

    def ld_runpath_search_paths
        return (ld_runpath_search_paths_original || []) + framework_search_paths
    end
end
