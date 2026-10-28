/* A stand-in Swift macro plugin. Built with -DHEALTHY it answers the compiler's capability
   probe; without it, it exits silently, like a plugin macOS killed at launch. */
#include <stdio.h>
#include <unistd.h>

int main(void) {
    char buffer[4096];
    while (read(0, buffer, sizeof buffer) > 0) {}
#ifdef HEALTHY
    fputs("{\"getCapabilityResult\":{\"capability\":{\"protocolVersion\":7}}}", stdout);
    return 0;
#else
    return 137;
#endif
}
