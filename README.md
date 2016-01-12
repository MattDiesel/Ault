# Ault
AutoIt Language Tools

Ault is a set of tools for parsing the AutoIt language, in AutoIt. The end aim is to create a library that can be used to easily write tools similar to Tidy (See the "deparser" for a simple version) in AutoIt, so they can be maintained by the community. 

This has been written very quickly, I'm a big fan of the idea that quantity always trumps quality. As a result it looks a lot closer to completion than it is. Just because it can parse 99% of scripts doesn't mean it can do so reliably and report errors correctly.

Mat

# AST Format

The AST format takes a bit of explaining. Due to nested arrays being painful and messy, and no other compound data structures existing, the syntax tree is stored as a flat array of branches, where "pointing" to a child branch means using its index. This is practically the same as having a block of memory and creating a normal tree structure.

Depending on the type of the branch, the VALUE, LEFT and RIGHT values have different meanings. The format is documented here: https://github.com/MattDiesel/Ault/wiki/AST-Format
