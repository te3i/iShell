import os

def trim(x, start, end):
    assert x.startswith(start)
    assert x.endswith(end)
    return x[len(start):-len(end)]

APK_REPOSITORIES = [
    ('v3.19', 'main'),
    ('v3.19', 'community'),
]
ARCH = 'x86' # TODO: support more archs

repos_file = []
repos_file.append('https://dl-cdn.alpinelinux.org/alpine/v3.19/main')
repos_file.append('https://dl-cdn.alpinelinux.org/alpine/v3.19/community')

with open(os.path.join(os.environ['BUILT_PRODUCTS_DIR'], os.environ['CONTENTS_FOLDER_PATH'], 'repositories.txt'), 'w') as f:
    for line in repos_file:
        print(line, file=f)
