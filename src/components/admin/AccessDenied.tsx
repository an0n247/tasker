import { motion } from "framer-motion";
import { ShieldAlert, ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Link } from "@tanstack/react-router";

export function AccessDenied() {
  return (
    <div className="min-h-[80vh] flex items-center justify-center px-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.5, ease: "easeOut" }}
        className="max-w-md w-full text-center space-y-8 bg-card p-10 rounded-3xl border border-border shadow-2xl shadow-destructive/5"
      >
        <motion.div
          animate={{
            scale: [1, 1.1, 1],
            rotate: [0, -5, 5, 0],
          }}
          transition={{
            duration: 4,
            repeat: Infinity,
            ease: "easeInOut",
          }}
          className="inline-flex p-6 rounded-full bg-destructive/10 text-destructive"
        >
          <ShieldAlert className="h-20 w-20" strokeWidth={1.5} />
        </motion.div>

        <div className="space-y-4">
          <motion.h2
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.2 }}
            className="text-4xl font-black uppercase tracking-tighter text-foreground"
          >
            Access Denied
          </motion.h2>
          <motion.p
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.3 }}
            className="text-muted-foreground font-medium text-lg leading-relaxed"
          >
            You don't have the required permissions to view this secure area. This attempt has been
            logged.
          </motion.p>
        </div>

        <motion.div
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.4 }}
        >
          <Button
            asChild
            size="lg"
            className="w-full h-14 rounded-2xl font-black uppercase tracking-widest text-[12px] shadow-lg shadow-primary/20 hover:shadow-xl hover:shadow-primary/30 transition-all duration-300"
          >
            <Link to="/">
              <ArrowLeft className="mr-2 h-4 w-4" />
              Return to Dashboard
            </Link>
          </Button>
        </motion.div>
      </motion.div>
    </div>
  );
}
