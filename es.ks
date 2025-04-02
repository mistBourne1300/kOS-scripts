list engines in engs.
for e in engs{
    if e:consumedresources:keys:find("oxidizer") < 0 {
    print e:name + e:consumedresources:keys[1].
    }
}