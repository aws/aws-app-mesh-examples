package com.example.stats;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import java.io.*;

@RestController
public class StatsController {
    @RequestMapping(value = "/stats/prometheus", method = RequestMethod.GET)
    public String getPromStats() throws IOException {
        //return ("hai");
        //InputStream is = new FileInputStream("stats");
        InputStream is = new FileInputStream("front.out");
        BufferedReader buf = new BufferedReader(new InputStreamReader(is));
        String line = buf.readLine();
        StringBuilder sb = new StringBuilder();
        while(line != null)
        {
            sb.append(line).append("\n");
            line = buf.readLine();
        }
        String fileAsString = sb.toString();

        return fileAsString;
    }
}
