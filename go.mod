module triwheel

go 1.24.7

require (
	github.com/jchv/go-webview2 v0.0.0-20260205173254-56598839c808
	golang.org/x/image v0.20.0
	golang.org/x/sys v0.25.0
	gopkg.in/yaml.v3 v3.0.1
)

replace github.com/jchv/go-webview2 => ./third_party/go-webview2
